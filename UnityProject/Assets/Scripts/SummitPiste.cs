using UnityEngine;
namespace SummitValley {
 public class SummitPiste:MonoBehaviour {
  public Vector3[] points; public Color color=Color.white;
  public void Build(SummitTerrain terrain){var lr=gameObject.AddComponent<LineRenderer>();lr.positionCount=points.Length;lr.startWidth=2.2f;lr.endWidth=2.2f;lr.material=Mat(color);for(int i=0;i<points.Length;i++){var p=points[i];p.y=terrain.Height(p.x,p.z)+.22f;lr.SetPosition(i,p);}}
  Material Mat(Color c){var m=new Material(Shader.Find("Standard"));m.color=c;m.enableInstancing=true;return m;}
 }
}