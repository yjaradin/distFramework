functor
export
   new:NewLKDic
   Is
   Put
   Get
   CondGet
   Exchange
   CondExchange
   Keys
   Entries
   Items
   IsEmpty
   Remove
   RemoveAll
   Member
   Clone
   'class':LKDic
define
   fun{NewLKDic}
      {New LKDic init()}
   end
   fun{Is D}
      {HasFeature D It} andthen D.It==It
   end
   proc{Put D Ks V}{D put(Ks V)}end
   proc{Get D Ks ?V}{D get(Ks V)}end
   proc{CondGet D Ks X ?V}{D condGet(Ks X V)}end
   proc{Exchange D Ks ?O N}{D exchange(Ks O N)}end
   proc{CondExchange D Ks X ?O N}{D condExchange(Ks X O N)}end
   proc{Keys D ?R}{D keys(R)}end
   proc{Entries D ?R}{D entries(R)}end
   proc{Items D ?R}{D items(R)}end
   proc{IsEmpty D ?R}{D isEmpty(R)}end
   proc{Remove D Ks}{D remove(Ks)}end
   proc{RemoveAll D}{D removeAll()}end
   proc{Member D Ks ?R}{D member(Ks R)}end
   proc{Clone D ?R}{D clone(R)}end
   It={NewName}
   EmptyDic={NewDictionary}
   class LKDic
      feat
	 !It
      attr
	 rootDic
	 sem
	 empty
      meth Do(P)
	 O N S in
	 O=sem:=N
	 N=S|{List.filter O IsFree}
	 {P}
	 S=unit
      end
      meth DoExcl(P)
	 O N in
	 O=sem:=N
	 {List.forAll O Wait}
	 {P}
	 N=nil
      end
      meth Lookup(Ks $)
	 {List.foldL Ks proc{$ D K N}
			   case {Dictionary.condExchange D K unit $ N}
			   of unit then
			      N={Dictionary.new}
			   [] O then
			      N=O
			   end
			end @rootDic}
      end
      meth LookupC(Ks X $)
	 fun{Loop D Ks}
	    case Ks
	    of nil then D
	    [] K|Kr then
	       case {Dictionary.condGet D K unit}
	       of unit then X
	       [] N then {Loop N Kr}
	       end
	    end
	 end
      in
	 {Loop @rootDic Ks}
      end
      meth init()
	 self.It=It
	 rootDic:={Dictionary.new}
	 empty:=true
	 sem:=nil
      end
      meth put(Ks V)
	 {self Do(proc{$}
		     empty:=false
		     {self Lookup(Ks $)}.It:=V
		  end)}
      end
      meth get(Ks R)
	 {self Do(proc{$}
		     R={List.foldL Ks Dictionary.get @rootDic}.It
		  end)}
      end
      meth condGet(Ks D R)
	 {self Do(proc{$}
		     R={self LookupC(Ks x(It:D) $)}.It
		  end)}
      end
      meth exchange(Ks O N)
	 {self Do(proc{$}
		     O={List.foldL Ks Dictionary.get @rootDic}.It:=N
		  end)}
      end
      meth condExchange(Ks D O N)
	 {self Do(proc{$}
		     empty:=false
		     {Dictionary.condExchange {self Lookup(Ks $)} It D O N}
		  end)}
      end
      meth keys($)
	 {Map {self entries($)} fun{$X}X.1 end}
      end
      meth entries(R)
	 {self DoExcl(proc{$}
			 Es={NewCell nil}
			 proc {Loop Ks D}
			    for K#E in {Dictionary.entries D} do
			       if K==It then
				  Es:=({List.reverse Ks}#E)|@Es
			       else
				  {Loop K|Ks E}
			       end
			    end
			 end
		      in
			 {Loop nil @rootDic}
			 R=@Es
		      end)}
      end
      meth items($)
	 {List.map {self entries($)} fun{$X}X.2 end}
      end
      meth isEmpty(R)
	 {self Do(proc{$}
		     R=@empty
		  end)}
      end
      meth remove(Ks)
	 {self DoExcl(proc{$}
			 proc{Loop D Ks}
			    case Ks
			    of nil then
			       {Dictionary.remove D It}
			    [] K|Kr then
			       {Loop {Dictionary.condGet D K EmptyDic} Kr}
			       if {Dictionary.isEmpty {Dictionary.condGet D K EmptyDic}} then
				  {Dictionary.remove D K}
			       end
			    end
			 end
		      in
			 {Loop @rootDic Ks}
			 if {Dictionary.isEmpty @rootDic} then empty:=true end
		      end)}
      end
      meth removeAll()
	 {self DoExcl(proc{$}
			 {Dictionary.removeAll @rootDic}
			 empty:=true
		      end)}
      end
      meth member(Ks R)
	 {self Do(proc{$}
		     R={Value.hasFeature {self LookupC(Ks x $)} It}
		  end)}
      end
      meth clone(R)
	 D={New LKDic init()}
      in
	 for Ks#X in {self entries($)} do
	    {D put(Ks X)}
	 end
	 R=D
      end
   end
end
