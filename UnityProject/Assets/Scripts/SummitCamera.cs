using UnityEngine;
namespace SummitValley {
 public class SummitCamera:MonoBehaviour {
  public Transform target;float yaw=42,pitch=42,distance=78;Vector2 last;
  void Start(){if(!target){var t=new GameObject("Camera Target");target=t.transform;target.position=new Vector3(0,10,0);}Apply();}
  void Update(){if(Input.touchCount==1){var t=Input.GetTouch(0);if(t.phase==TouchPhase.Moved){yaw-=t.deltaPosition.x*.18f;pitch=Mathf.Clamp(pitch-t.deltaPosition.y*.12f,25,70);Apply();}}if(Input.mousePresent&&Input.GetMouseButton(0)){yaw-=Input.GetAxis("Mouse X")*3;pitch=Mathf.Clamp(pitch+Input.GetAxis("Mouse Y")*2,25,70);Apply();}}
  void Apply(){float y=yaw*Mathf.Deg2Rad,p=pitch*Mathf.Deg2Rad;transform.position=target.position+new Vector3(Mathf.Sin(y)*Mathf.Cos(p)*distance,Mathf.Sin(p)*distance,Mathf.Cos(y)*Mathf.Cos(p)*distance);transform.LookAt(target);}
 }
}