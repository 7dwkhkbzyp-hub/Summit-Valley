using UnityEngine;
namespace SummitValley {
 public class SummitEconomy:MonoBehaviour {
  public int cash=24800; public int guests=60; public float reputation=72;
  float timer;
  void Update(){timer+=Time.deltaTime;if(timer>1){timer=0;cash+=Mathf.RoundToInt(guests*.45f);reputation=Mathf.Clamp(reputation+.01f,0,100);}}
  public void Spend(int amount){cash-=amount;}
 }
}