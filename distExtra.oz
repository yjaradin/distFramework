functor
import
   DistBase at 'distBase.ozf'
export
   Load
define
   Services=DistBase.services
   
   class SP2P
      from DistBase.p2p
      attr
	 flp2p
	 sent
      meth init(flp2p:Ref<=unit)
	 if Ref==unit then
	    @flp2p={@this newService(flp2p() {self wrap(deliver:Deliver $)} $)}
	 else
	    @flp2p={@this serviceFromRef(Ref {self wrap(deliver:Deliver $)} $)}
	 end
	 @sent=nil
	 thread {Delay 1000} {self Timeout()} end
      end 
      meth Timeout()
	 for Dest#M in @sent do
	    {@flp2p send(Dest M)}
	 end
	 {Delay 1000}
	 {self Timeout()}
      end
      meth send(Dest Msg)
	 OldSent in
	 {@flp2p send(Dest Msg)}
	 OldSent=sent:=(Dest#Msg)|OldSent
      end
      meth Deliver(Src Msg)
	 {@up deliver(Src Msg)}
      end
      meth getRefParams($)
	 init(flp2p:{@flp2p getRef($)})
      end
   end
   Services.sp2p:=SP2P

   class BookPP2P
      from DistBase.p2p
      attr
	 sp2p
	 delivered
      meth init(sp2p:Ref<=unit)
	 if Ref==unit then
	    @sp2p={@this newService(sp2p() {self wrap(deliver:Deliver $)} $)}
	 else
	    @sp2p={@this serviceFromRef(Ref {self wrap(deliver:Deliver $)} $)}
	 end
	 @delivered={Dictionary.new}
      end
      meth send(Dest Msg)
	 {@sp2p send(Dest m({NewName} Msg))}
      end
      meth Deliver(Src Msg)
	 case Msg
	 of m(Mid Content) then
	    if {Not {Dictionary.condExchange @delivered Mid false $ true}} then
	       {@up deliver(Content)}
	    end
	 end
      end
      meth getRefParams($)
	 init(sp2p:{@sp2p getRef($)})
      end
   end
   Services.book_pp2p:=BookPP2P

   fun{Lowest Def Dic}
      {List.foldL {Dictionary.keys Dic} Min Def}
   end
   class SmarterPP2P
      from DistBase.p2p
      attr
	 down
	 partners
      meth init(down:Ref<=unit)
	 if Ref==unit then
	    @down={@this newService(flp2p() {self wrap(deliver:Deliver $)} $)}
	 else
	    @down={@this serviceFromRef(Ref {self wrap(deliver:Deliver $)} $)}
	 end
	 @partners={Dictionary.new}
	 thread {Delay 1000} {self Timeout()} end
      end
      meth Timeout()
	 for P in {Dictionary.items @partners} do
	    for M in {Dictionary.items P.sending} do
	       {@down M}
	    end
	    for M in {Dictionary.items P.ackSending} do
	       {@down M}
	    end
	 end
	 {Delay 1000}
	 {self Timeout()}
      end
      meth Partner(P $)
	 case {Dictionary.condGet @partners P.pid unit}
	 of unit then N in
	    case {Dictionary.condExchange @partners P.pid unit $ N}
	    of unit then
	       N=p(nextSendId:{NewCell 0}
		   lastSent:{NewCell 0}
		   sending:{Dictionary.new}
		   acceptableId:{NewCell 0}
		   delivered:{Dictionary.new}
		   ackSending:{Dictionary.new})
	       N
	    [] R then N=R R
	    end
	 [] R then R
	 end
      end
      meth send(Dest Msg)
	 P={self Partner(Dest $)}
	 ThisId NextId
	 OldLast NewLast
      in
	 ThisId=(P.nextSendId):=NextId
	 NextId=ThisId+1
	 P.sending.ThisId:=send(Dest msg(ThisId Msg))
	 OldLast=(P.lastSent):=NewLast
	 NewLast={Max OldLast ThisId}
	 {@down send(Dest msg(ThisId Msg))}
      end
      meth Deliver(Src Msg)
	 P={self Partner(Src $)}
      in
	 case Msg
	 of msg(Mid Cont) then
	    if Mid>=@(P.acceptableId) andthen
	       {Not {Dictionary.condExchange P.delivered Mid false $ true}} then
	       {@up deliver(Src Cont)}
	       P.ackSending.Mid:=send(Src ack(Mid))
	    end	
	    {@down send(Src ack(Mid))}
	 [] ack(Mid) then
	    {Dictionary.remove P.sending Mid}
	    {@down send(Src ackack(Mid {Lowest @(P.lastSent) P.sending}))}
	 [] ackack(Mid Nid) then
	    OldAccId NewAccId in
	    {Dictionary.remove P.ackSending Mid}
	    OldAccId=(P.acceptableId):=NewAccId
	    NewAccId={Max OldAccId Nid}
	    for K in {Dictionary.keys P.delivered} do
	       if K<NewAccId then
		  {Dictionary.remove P.delivered K}
	       end
	    end
	 end
      end
      meth getRefParams($)
	 init(down:{@down getRef($)})
      end
   end
   Services.pp2p:=SmarterPP2P

   class EPFD
      from DistBase.baseService
      attr
	 down
	 all
	 alive
	 suspected
	 period
	 newPeriod
      meth init(down:Ref<=unit)
	 if Ref==unit then
	    @down={@this newService(pp2p() {self wrap(deliver:Deliver $)} $)}
	 else
	    @down={@this serviceFromRef(Ref {self wrap(deliver:Deliver $)} $)}
	 end
	 @all={Dictionary.new}
	 @alive={Dictionary.new}
	 @suspected={Dictionary.new}
	 @period=@newPeriod=3000
	 thread {Delay @period} {self Timeout()} end
      end
      meth Timeout()
	 for X in {Dictionary.keys @all} do
	    if {Not {HasFeature @suspected X}} andthen
	       {Not {HasFeature @alive X}} then
	       suspected.X:=true
	       {@up suspect(all.X)}
	    elseif {HasFeature @suspected X} andthen
	       {HasFeature @alive X} then
	       newPeriod:=@period+500
	       {Dictionary.remove @suspected X}
	       {@up restore(all.X)}
	    end
	    {@down send(all.X unit)}
	 end
	 {Dictionary.removeAll @alive}
	 period:=@newPeriod
	 {Delay @period}
	 {self Timeout()}
      end
      meth Deliver(Src _)
	 alive.(Src.pid):=true
      end
      meth monitor(Ps)
	 for P in Ps do
	    {@down send(P unit)}
	 end
	 thread
	    {Delay @period}
	    for P in Ps do
	       all.(P.pid):=P
	    end
	 end
      end
      meth getRefParams($)
	 init(down:{@down getRef($)})
      end
   end
   Services.epfd:=EPFD

   fun{Best Ps}
      case Ps
      of [A] then A
      [] A|B|T then
	 PA=A.pid PB=B.pid in
	 if {Arity f(PA:a PB:b)}==[PA PB] then
	    {Best A|T}
	 else
	    {Best B|T}
	 end
      end
   end
   class ELD
      from
	 DistBase.baseService
      attr
	 down
	 all
	 alive
	 current
      meth init(Ps down:Ref<=unit)
	 if Ref==unit then
	    @down={@this newService(epfd() {self wrap(suspect:Suspect
						      restore:Restore $)} $)}
	 else
	    @down={@this serviceFromRef(Ref {self wrap(suspect:Suspect
						       restore:Restore $)} $)}
	 end
	 {@down monitor(Ps)}
	 @all={Dictionary.new}
	 @alive={Dictionary.new}
	 for P in Ps do
	    all.(P.pid):=P
	    alive.(P.pid):=P
	 end
	 if {Not {HasFeature @all @thisP.pid}} then
	    raise eld_localProcessNotIncluded end
	 end
	 @current={Best {Dictionary.items @alive}}
	 {@up trust(@current)}
      end
      meth Suspect(P)
	 NewCur OldCur in
	 {Dictionary.remove @alive P.pid}
	 OldCur=current:=NewCur
	 NewCur={Best {Dictionary.items @alive}}
	 if NewCur\=OldCur then
	    {@up trust(NewCur)}
	 end
      end
      meth Restore(P)
	 NewCur OldCur in
	 alive.(P.pid):=P
	 OldCur=current:=NewCur
	 NewCur={Best {Dictionary.items @alive}}
	 if NewCur\=OldCur then
	    {@up trust(NewCur)}
	 end
      end
      meth getRefParams($)
	 init({Dictionary.items @all} down:{@down getRef($)})
      end
   end
   Services.eld:=ELD

   class BCast from DistBase.baseService end

   class BEB
      from BCast
      attr
	 down
	 all
      meth init(Ps down:Ref<=unit)
	 if Ref==unit then
	    @down={@this newService(pp2p() {self wrap(deliver:Deliver $)} $)}
	 else
	    @down={@this serviceFromRef(Ref {self wrap(deliver:Deliver $)} $)}
	 end
	 @all=Ps
      end
      meth broadcast(Msg)
	 for P in @all do
	    {@down send(P Msg)}
	 end
      end
      meth Deliver(Src Msg)
	 {@up deliver(Src Msg)}
      end
      meth getRefParams($)
	 init(@all down:{@down getRef($)})
      end
   end
   Services.beb:=BEB

   class RB
      from BCast
      attr
	 down
	 delivered
      meth init(Ps<=nil down:Ref<=unit)
	 if Ref==unit then
	    if {Not {Member @thisP Ps}} then
	       raise rb_localProcessNotIncluded end
	    end
	    @down={@this newService(beb(Ps) {self wrap(deliver:Deliver $)} $)}
	 else
	    @down={@this serviceFromRef(Ref {self wrap(deliver:Deliver $)} $)}
	 end
	 @delivered={Dictionary.new}
      end
      meth broadcast(Msg)
	 Mid={NewName} in
	 @delivered.Mid:=true
	 {@up deliver(@thisP Msg)}
	 {@down broadcast(m(Mid @thisP Msg))}
      end
      meth Deliver(_ Msg)
	 case Msg
	 of m(Mid Src Content) then
	    if {Not {Dictionary.condExchange @delivered Mid false $ true}} then
	       {@up deliver(Src Content)}
	       {@down broadcast(Msg)}
	    end
	 end
      end
      meth getRefParams($)
	 init(down:{@down getRef($)})
      end
   end
   Services.rb:=RB

   proc{AddAck D K F}
      DK=
      case {Dictionary.condGet D K unit}
      of unit then N in
	 case {Dictionary.condExchange D K unit $ N}
	 of unit then T in
	    T={Dictionary.new}
	    T.count:=0
	    N=T
	 [] R then N=R R
	 end
      [] R then R
      end
   in
      if {Not {Dictionary.condExchange DK F false $ true}} then
	 O N in
	 O=DK.count:=N
	 N=O+1
      end
   end
   class URB
      from BCast
      attr
	 down
	 quorum
	 delivered
	 pending
	 ack
      meth init(Ps<=nil down:Ref<=unit quorum:Q<=unit)
	 if Ref==unit then
	    if {Not {Member @thisP Ps}} then
	       raise urb_localProcessNotIncluded end
	    end
	    @down={@this newService(beb(Ps) {self wrap(deliver:Deliver $)} $)}
	    @quorum=({Length Ps}+1) div 2
	 else
	    @down={@this serviceFromRef(Ref {self wrap(deliver:Deliver $)} $)}
	    @quorum=Q
	 end
	 @delivered={Dictionary.new}
	 @pending={Dictionary.new}
	 @ack={Dictionary.new}
      end
      meth broadcast(Msg)
	 Mid={NewName} in
	 @pending.Mid:=deliver(@thisP Msg)
	 {@down broadcast(m(Mid @thisP Msg))}
      end
      meth Deliver(From Msg)
	 case Msg
	 of m(Mid Src Content) then
	    {AddAck @ack Mid Src.pid}
	    case {Dictionary.condExchange @pending Mid unit $ deliver(Src Content)}
	    of unit then
	       {@down broadcast(Msg)}
	    else skip
	    end
	    if ack.Mid.count>=@quorum andthen
	       {Not {Dictionary.condExchange delivered Mid false $ true}} then
	       {@up pending.Mid}
	    end
	 end
      end
      meth getRefParams($)
	 init(down:{@down getRef($)} quorum:@quorum)
      end
   end
   Services.urb:=URB

   class RCO
      from BCast
      prop locking
      attr
	 down
	 vc
	 pending
      meth init(Ps<=unit down:Ref<=unit)
	 if Ref\=unit then
	    @down={@this serviceFromRef(Ref {self wrap(deliver:Deliver $)} $)}
	 elseif Ps\=unit then
	    @down={@this newService(rb(Ps) {self wrap(deliver:Deliver $)} $)}
	 else
	    raise rco_hostsListMissing end
	 end
	 @vc={Dictionary.new}
	 @pending={Dictionary.new}
      end
      meth Bump(P)
	 N in
	 N={Dictionary.condExchange @vc P.pid 0 $ N}+1
      end
      meth broadcast(Msg)
	 lock
	    {@up deliver(@thisP Msg)}
	    {@down broadcast(m({Dictionary.entries @vc} Msg))}
	    {self Bump(@thisP)}
	 end
      end
      meth Deliver(Src Msg)
	 lock
	    case Msg
	    of m(VC Content) then
	       if Src\=@thisP then
		  Redo={NewCell false}
		  proc{DeliverPending}
		     Redo:=false
		     for K#p(Src VC Content) in {Dictionary.entries @pending} do
			if {List.all VC fun{$ P#V}
					   {Dictionary.condGet @vc P 0}>=V
					end} then
			   {Dictionary.remove @pending K}
			   {@up deliver(Src Content)}
			   {self Bump(Src)}
			   Redo:=true
			end
		     end
		     if @Redo then {DeliverPending} end
		  end in
		  @pending.{NewName}:=p(Src VC Content)
		  {DeliverPending}
	       end
	    end
	 end
      end
      meth getRefParams($)
	 init(down:{@down getRef($)})
      end
   end
   Services.rco:=RCO

   class UCO
      from BCast
      prop locking
      attr
	 down
	 vc
	 pending
	 del
      meth init(Ps<=unit down:Ref<=unit)
	 if Ref\=unit then
	    @down={@this serviceFromRef(Ref {self wrap(deliver:Deliver $)} $)}
	 elseif Ps\=unit then
	    @down={@this newService(urb(Ps) {self wrap(deliver:Deliver $)} $)}
	 else
	    raise uco_hostsListMissing end
	 end
	 @vc={Dictionary.new}
	 @pending={Dictionary.new}
	 @del=0
      end
      meth Bump(P)
	 N in
	 N={Dictionary.condExchange @vc P.pid 0 $ N}+1
      end
      meth broadcast(Msg)
	 lock
	    {@down broadcast(m({Dictionary.entries @vc} Msg))}
	    {self Bump(@thisP)}
	 end
      end
      meth Deliver(Src Msg)
	 lock
	    case Msg
	    of m(VC Content) then
	       Redo={NewCell false}
	       proc{DeliverPending}
		  Redo:=false
		  for K#p(Src VC Content) in {Dictionary.entries @pending} do
		     if {List.all VC fun{$ P#V}
					{Dictionary.condGet @vc P 0}>=V andthen
					(P\=@thisP orelse @del>=V)
				     end} then
			{Dictionary.remove @pending K}
			{@up deliver(Src Content)}
			if Src\=@thisP then
			   {self Bump(Src)}
			else N in
			   N=(del:=N)+1
			end
			Redo:=true
		     end
		  end
		  if @Redo then {DeliverPending} end
	       end in
	       @pending.{NewName}:=p(Src VC Content)
	       {DeliverPending}
	    end
	 end
      end
      meth getRefParams($)
	 init(down:{@down getRef($)})
      end
   end
   Services.uco:=UCO

   proc{Load}skip end
end