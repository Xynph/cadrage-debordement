#!/usr/bin/env python3
"""Compare raw-world skinned GLB positions on all clips at 9 times + near end.
Requires NumPy/SciPy. Read-only inputs; fixed mapping from static skinned points.
One skin, skinned mesh instances only, no morph targets. Complete oriented-face
multisets and corresponding corner normals are checked at rest, including
degenerate triangles. CPU evidence is not graphical/GPU reception.
"""
import argparse,json,hashlib,os,tempfile
from collections import Counter
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import maximum_bipartite_matching
from skin_math import Glb

def match_oriented_corners(source_faces,candidate_faces,candidate_matches,source_normals,candidate_normals,normal_threshold=0.001):
 """Fixed rest-space matching of complete oriented faces, including corner normals.

 Seam duplicates may merge, but each source face must have exactly one candidate
 face. Only cyclic rotations are equivalent; a winding reversal is not. Position,
 material and semantic weight compatibility are precomputed in candidate_matches.
 No animation-time remapping or best-pose search is performed.
 """
 incidence={}
 for face_id,(material,triangle) in enumerate(source_faces):
  for vertex in triangle:incidence.setdefault((material,vertex),set()).add(face_id)
 geometry_edges=[];normal_edges=[];edge_angles={};geometry_angles={}
 for candidate_id,(material,triangle) in enumerate(candidate_faces):
  possible=None
  for vertex in triangle:
   adjacent=set()
   for source_id in candidate_matches[vertex]:adjacent.update(incidence.get((material,source_id),()))
   possible=adjacent if possible is None else possible & adjacent
  for source_id in sorted(possible or ()):
   original=source_faces[source_id][1];best=None;geometry=False
   for rotation in range(3):
    aligned=original[rotation:]+original[:rotation]
    if not all(sv in candidate_matches[cv] for sv,cv in zip(aligned,triangle)):continue
    geometry=True
    angle=max(float(np.arccos(np.clip(np.dot(source_normals[sv],candidate_normals[cv]),-1,1))) for sv,cv in zip(aligned,triangle))
    best=angle if best is None else min(best,angle)
   if geometry:
    geometry_edges.append((candidate_id,source_id));geometry_angles[(candidate_id,source_id)]=best
   if best is not None and best<=normal_threshold:
    normal_edges.append((candidate_id,source_id));edge_angles[(candidate_id,source_id)]=best
 def matching(edges):
  if not edges or not source_faces or not candidate_faces:return np.full(len(candidate_faces),-1,dtype=int)
  rows,cols=zip(*edges)
  graph=csr_matrix((np.ones(len(edges),dtype=np.int8),(rows,cols)),shape=(len(candidate_faces),len(source_faces)))
  return maximum_bipartite_matching(graph,perm_type='column')
 geometry_match=matching(geometry_edges);normal_match=matching(normal_edges)
 geometry_count=int(np.count_nonzero(geometry_match>=0));normal_count=int(np.count_nonzero(normal_match>=0))
 same_count=len(source_faces)==len(candidate_faces) and len(source_faces)>0
 return {'oriented_faces_equal':same_count and geometry_count==len(source_faces),
         'corner_normals_equal':same_count and normal_count==len(source_faces),
         'source_face_count':len(source_faces),'candidate_face_count':len(candidate_faces),
         'matched_geometry_faces':geometry_count,'matched_normal_faces':normal_count,
         'unmatched_normal_candidate_faces':[{'face':i,'material':candidate_faces[i][0],'corners':candidate_faces[i][1],'best_corner_normal_angle_rad':min((angle for (ci,si),angle in geometry_angles.items() if ci==i),default=None)} for i,j in enumerate(normal_match) if j<0][:10],
         'unmatched_normal_source_faces':[{'face':i,'material':source_faces[i][0],'corners':source_faces[i][1]} for i in range(len(source_faces)) if i not in set(int(j) for j in normal_match if j>=0)][:10],
         'max_matched_corner_normal_angle_rad':max((edge_angles[(i,int(j))] for i,j in enumerate(normal_match) if j>=0),default=None),
         'face_mapping':'one-to-one oriented triangles at rest; normal bound applies to each corresponding corner'}

def face_rows(glb):
 rows=[];offset=0
 for node in glb.nodes:
  if 'mesh' not in node or 'skin' not in node:continue
  for primitive in glb.d['meshes'][node['mesh']]['primitives']:
   if primitive.get('mode',4)!=4:raise ValueError('Only triangle primitives supported')
   count=len(glb.acc(primitive['attributes']['POSITION']))
   indices=glb.acc(primitive['indices']).reshape(-1) if 'indices' in primitive else np.arange(count)
   if len(indices)%3 or np.any(indices<0) or np.any(indices>=count):raise ValueError('Invalid triangle indices')
   material=glb.d['materials'][primitive['material']].get('name',str(primitive['material']))
   rows.extend((material,tuple(offset+int(k) for k in triangle)) for triangle in indices.reshape(-1,3))
   offset+=count
 return rows

def validate_skin_scope(glb):
 """Reject geometry ignored by this deliberately narrow one-skin CPU model."""
 if len(glb.d.get('skins',[]))!=1:raise ValueError('CPU skin contract requires exactly one skin')
 if any('mesh' in node and 'skin' not in node for node in glb.nodes):
  raise ValueError('Unskinned mesh instances are outside the CPU skin contract')
 if any(primitive.get('targets') for mesh in glb.d.get('meshes',[]) for primitive in mesh.get('primitives',[])):
  raise ValueError('Morph targets are outside the CPU skin contract')
 if any(channel.get('target',{}).get('path')=='weights' for animation in glb.d.get('animations',[]) for channel in animation.get('channels',[])):
  raise ValueError('Morph weight animations are outside the CPU skin contract')
 names=[glb.nodes[i].get('name') for i in glb.d['skins'][0]['joints']]
 if None in names or len(names)!=len(set(names)):raise ValueError('Unique semantic joint names required')

def compare(src,cand,epsilon=1e-5,weight_epsilon=1e-5,tolerance=1e-4):
 before={str(Path(p).resolve()):hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in (src,cand)}
 s=Glb(src);c=Glb(cand);validate_skin_scope(s);validate_skin_scope(c);sp,sm=s.sample();cp,cm=c.sample();tree=cKDTree(cp);mapping=[];unmatched=[];ambiguous=0;maxrest=0.;maxweight=0.
 for k,(point,meta) in enumerate(zip(sp,sm)):
  possibles=[]
  for j in tree.query_ball_point(point,epsilon):
   other=cm[j]
   if meta[0]!=other[0]:continue
   wa,wb=dict(meta[1]),dict(other[1]);we=max(abs(wa.get(b,0)-wb.get(b,0)) for b in wa.keys()|wb.keys())
   if we<=weight_epsilon:possibles.append((float(np.linalg.norm(point-cp[j])),j,we))
  if not possibles:unmatched.append(k);mapping.append(0);continue
  possibles.sort();distance,j,we=possibles[0];mapping.append(j);maxrest=max(maxrest,distance);maxweight=max(maxweight,we);ambiguous+=len(possibles)>1

 def normal_rows(glb):
  return np.concatenate([glb.acc(pr['attributes']['NORMAL']) for n in glb.nodes if 'mesh' in n and 'skin' in n for pr in glb.d['meshes'][n['mesh']]['primitives']])
 def topology_counts(glb):
  counts=Counter()
  for node in glb.nodes:
   if 'mesh' not in node or 'skin' not in node:continue
   for pr in glb.d['meshes'][node['mesh']]['primitives']:
    if pr.get('mode',4)!=4:raise ValueError('Only triangle primitives supported')
    mat=glb.d['materials'][pr['material']].get('name',str(pr['material']))
    index_count=len(glb.acc(pr['indices'])) if 'indices' in pr else len(glb.acc(pr['attributes']['POSITION']))
    if index_count%3:raise ValueError('Invalid triangle index count')
    counts[(mat,'triangles')]+=index_count//3;counts[(mat,'primitives')]+=1
  return counts
 sn,cn=normal_rows(s),normal_rows(c)
 if not all(np.all(np.isfinite(x)) for x in (sp,cp,sn,cn)):raise ValueError('Non-finite geometry')
 if any(np.any(np.linalg.norm(x,axis=1)<1e-12) for x in (sn,cn)):raise ValueError('Zero normals')
 sn=sn/np.linalg.norm(sn,axis=1)[:,None];cn=cn/np.linalg.norm(cn,axis=1)[:,None]
 def compatible(a,b):
  if a[0]!=b[0]:return False
  wa,wb=dict(a[1]),dict(b[1]);return max(abs(wa.get(j,0)-wb.get(j,0)) for j in wa.keys()|wb.keys())<=weight_epsilon
 reverse_tree=cKDTree(sp);candidate_unmatched=[];normal_angles=[];candidate_matches=[]
 for j,point in enumerate(cp):
  matches=[k for k in reverse_tree.query_ball_point(point,epsilon) if compatible(sm[k],cm[j])]
  candidate_matches.append(set(matches))
  if not matches:candidate_unmatched.append(j);continue
  normal_angles.append(float(np.arccos(np.clip(max(np.dot(sn[k],cn[j]) for k in matches),-1,1))))
 source_normal_missing=0
 for k,point in enumerate(sp):
  matches=[j for j in tree.query_ball_point(point,epsilon) if compatible(sm[k],cm[j])]
  if not matches:source_normal_missing+=1;continue
  normal_angles.append(float(np.arccos(np.clip(max(np.dot(sn[k],cn[j]) for j in matches),-1,1))))
 # Raw normals may only be compared directly if inverse-bind bases agree.
 sb={s.nodes[j]['name']:v for sk in s.d.get('skins',[]) for j,v in zip(sk['joints'],s.acc(sk['inverseBindMatrices']))}
 cb={c.nodes[j]['name']:v for sk in c.d.get('skins',[]) for j,v in zip(sk['joints'],c.acc(sk['inverseBindMatrices']))}
 bases_equal=set(sb)==set(cb) and all(np.max(np.abs(sb[n]-cb[n]))<=1e-5 for n in sb)
 normal_max=max(normal_angles,default=float('inf'));normal_pass=bases_equal and not candidate_unmatched and not source_normal_missing and normal_max<=0.001
 clip_s,clip_c=s.clips(),c.clips();clip_contract=set(clip_s)==set(clip_c) and all(abs(t-clip_c[n])<=1e-5 for n,t in clip_s.items())
 topology_pass=topology_counts(s)==topology_counts(c) and len(s.d['meshes'])==len(c.d['meshes'])

 corner_contract=match_oriented_corners(face_rows(s),face_rows(c),candidate_matches,sn,cn)
 oriented_faces_equal=corner_contract['oriented_faces_equal']
 topology_pass=topology_pass and oriented_faces_equal
 normal_pass=normal_pass and corner_contract['corner_normals_equal']
 out={'units':'raw GLB world units, not gameplay metres','source_points':len(sp),'candidate_points':len(cp),'mapping':'fixed rest skinned position + material name + semantic joint names/weights','mapping_epsilon':epsilon,'weight_epsilon':weight_epsilon,'unmatched':len(unmatched),'ambiguous_equivalent_duplicates':ambiguous,'max_rest_distance':maxrest,'max_weight_difference':maxweight,'threshold':tolerance,'samples':[],'passed':False}
 out.update(corner_contract)
 out.update(candidate_unmatched=len(candidate_unmatched),topology_counts_equal=topology_pass,clip_contract_equal=clip_contract,normal_basis_equal=bases_equal,max_normal_angle_rad=normal_max,normal_threshold_rad=0.001,normals_passed=normal_pass)
 if unmatched:out['first_unmatched']=unmatched[:10]
 valid=np.array([i for i in range(len(mapping)) if i not in unmatched]);idx=np.array(mapping)[valid];maximum=0.;thumb=np.array([any('Thumb' in b for b,weight in meta[1]) for meta in [sm[i] for i in valid]])
 for clip,duration in s.clips().items():
  if clip not in c.clips():out['missing_clip']=clip;return out
  for t in sorted(set([*np.linspace(0,duration,9),max(0,duration-1e-4)])):
   ps,_=s.sample(clip,float(t));pc,_=c.sample(clip,float(t))
   if not np.all(np.isfinite(ps)) or not np.all(np.isfinite(pc)):raise ValueError('Non-finite animated geometry')
   errors=np.linalg.norm(ps[valid]-pc[idx],axis=1);maximum=max(maximum,float(max(errors)));out['samples'].append({'clip':clip,'t':float(t),'max':float(max(errors)),'thumb_max':float(max(errors[thumb]))})
 out['sampled_poses']=len(out['samples']);out['compared_vertices_per_pose']=len(valid);out['clips_compared']=len(s.clips());out['all_source_clips_compared']=set(s.clips())==set(c.clips());out['max_skinned_distance']=maximum;out['passed']=not unmatched and not candidate_unmatched and maximum<=tolerance and clip_contract and topology_pass and normal_pass;out['input_sha256']=before
 if any(hashlib.sha256(Path(p).read_bytes()).hexdigest()!=digest for p,digest in before.items()):raise RuntimeError('Input changed during comparison')
 out['inputs_unchanged']=True;return out

if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('source');ap.add_argument('candidate');ap.add_argument('--out',required=True);args=ap.parse_args();output=Path(args.out).resolve()
 if any(output==Path(p).resolve() or (output.exists() and output.samefile(p)) for p in (args.source,args.candidate)):ap.error('Output aliases an input')
 r=compare(args.source,args.candidate)
 with tempfile.NamedTemporaryFile(mode='w',dir=output.parent,delete=False,prefix='.skin-',suffix='.json') as handle:
  tmp=Path(handle.name);handle.write(json.dumps(r,indent=2)+'\n')
 try:os.replace(tmp,output)
 finally:tmp.unlink(missing_ok=True)
 print(json.dumps({k:v for k,v in r.items() if k!='samples'},indent=2));raise SystemExit(0 if r['passed'] else 1)
