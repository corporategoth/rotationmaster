// In-memory sliding-window rate limiter. One process only; a multi-instance
// deployment needs a shared limiter (see Web/DECISIONS.md).
export function createRateLimiter({clock=()=>Date.now(),maxKeys=50000}={}){
  const hits=new Map();
  return {
    // Returns {ok:true} and records a hit, or {ok:false,retryAfter} seconds.
    take(bucket,key,{limit,windowSeconds}){
      if(!limit||limit<=0)return {ok:true};
      const id=bucket+'\u0000'+key,now=clock(),floor=now-windowSeconds*1000;
      let list=hits.get(id);
      if(list){while(list.length&&list[0]<=floor)list.shift();}
      else{
        if(hits.size>=maxKeys)for(const [k,v] of hits){if(!v.length||v[v.length-1]<=floor)hits.delete(k);if(hits.size<maxKeys)break;}
        list=[];hits.set(id,list);
      }
      if(list.length>=limit)return {ok:false,retryAfter:Math.max(1,Math.ceil((list[0]+windowSeconds*1000-now)/1000))};
      list.push(now);return {ok:true};
    },
    reset(){hits.clear();},
  };
}
