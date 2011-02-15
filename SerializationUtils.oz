functor
export
   ToAlpha
   FromAlpha
   CompleteTokens
define
   fun{ToAlpha S T}
      fun{Loop Xs}
	 case Xs
	 of nil then T
	 [] X|Xr
	    andthen X>=0
	    andthen X<256 then
	    (X div 16)+&a|(X mod 16)+&a|{Loop Xr}
	 end
      end
   in
      {Loop {VirtualString.toString S}}
   end
   fun{FromAlpha Xs T}
      case Xs
      of nil then
	 T=nil
	 nil
      [] X|_ andthen (X<&a orelse X>&a+16) then
	 T=Xs
	 nil
      [] Xh|Xl|Xr
	 andthen Xh>=&a andthen Xh<&a+16
	 andthen Xl>=&a andthen Xl<&a+16 then
	 ((Xh-&a)*16+(Xl-&a))|{FromAlpha Xr T}
      end
   end
   fun{CompleteTokens Xs D}
      T H={FromAlpha Xs T} in
      case T
      of nil then nil
      [] X|Xr andthen {Member X D} then
	 (H#X)|{CompleteTokens Xr D}
      end
   end
end