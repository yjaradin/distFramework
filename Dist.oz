functor
import
   DistFramework(session:Session)
   LKDictionary
   Pickle
   SerializationUtils(toAlpha:ToAlpha
		      fromAlpha:FromAlpha)
export
   Pp2p
   Pfd
   Process
   Ifd
   Bep2p
   Comm
define
   fun{DontCare}_ end
   fun{Pp2p LM ?Uri}
   BEP2P={LM getLayer('dist-layer:bep2p' $)}
   Alarm={LM getLayer('dist-layer:alarm' $)}
   UUID='pp2p(f4db69a4-fb75-4465-a365-9e5eae154b25)'
   RETRANSMIT=100
in
   Uri='dist-layer:pp2p'
   class from Session
      attr
	 h
	 bep2p alarm
	 toSend
	 nextId
	 receiveCutIds
	 sendCutId
	 delivered
      meth init(SId Handler)
	 h:=Handler
	 bep2p:={BEP2P init(UUID|bep2p|SId {self facet(bep2pDeliver:Deliver $)})}
	 alarm:={Alarm init(UUID|alarm|SId {self facet(alarm:OnAlarm $)})}
	 toSend:={NewDictionary}
	 delivered:={NewDictionary}
	 nextId:=0 receiveCutIds:={NewDictionary} sendCutId:=0
      end
      meth pp2pSend(To Msg)
	 Id=@nextId in
	 nextId:=Id+1
	 @toSend.Id:=m(Id To Msg)
	 {@bep2p bep2pSend(To m(Id Msg @sendCutId))}
	 {@alarm setAlarmIn(RETRANSMIT Id)}
      end
      meth OnAlarm(Id)
	 if {HasFeature @toSend Id} then
	    m(!Id To Msg)=@toSend.Id in
	    {@bep2p bep2pSend(To m(Id Msg @sendCutId))}
	    {@alarm setAlarmIn(RETRANSMIT Id)}
	 end
      end
      meth Deliver(From Msg)
	 case Msg
	 of m(Id Msg CutId) then
	    RCutId={Dictionary.condGet @receiveCutIds From.id 0}
	    if{Not{HasFeature @delivered From.id}} then
	       @delivered.(From.id):={NewDictionary}
	    end
	    Delivered=@delivered.(From.id)
	 in
	    if Id>=RCutId andthen {Not {HasFeature Delivered Id}} then
	       Delivered.Id:=true
	       {@h pp2pDeliver(From Msg)}
	    end
	    if CutId>RCutId then
	       for I in RCutId..CutId-1 do
		  {Dictionary.remove Delivered I}
	       end
	       @receiveCutIds.(From.id):=CutId
	    end
	    {@bep2p bep2pSend(From ack(Id))}
	 [] ack(Id) then
	    {Dictionary.remove @toSend Id}
	    if Id==@sendCutId then
	       sendCutId:=
	       for I in Id..@nextId return:R default:@nextId do
		  if {HasFeature @toSend I} then {R I} end
	       end
	    end
	 end
      end
   end
end
fun{Pfd LM ?Uri}
   UUID='pfd(849cb908-5ccd-4218-9eef-fe289f07ee44)'
   _={{LM getLayer('dist-layer:comm-interface' $)} init(Handler)}
   PP2P={LM getLayer('dist-layer:pp2p' $)}
   IFD={LM getLayer('dist-layer:ifd' $)}
   Alarm={{LM getLayer('dist-layer:alarm' $)} init([UUID alarm] TimerHandler)}
   Monitors={NewDictionary}
   proc{Handler M}
      case M
      of deliver(_ _) then skip
      [] amIAlive(S) then
	 Now={Alarm getTime($)} in
	 S={All {Dictionary.items Monitors} fun{$ MaxT}Now<MaxT end}
      [] iAmDead then skip
      end
   end
   proc{TimerHandler alarm(S)}
      {S check()}
   end
   SURVIVABILITY=30*1000
   SKEW=2
in
   Uri='dist-layer:pfd'
   class from Session
      attr
	 h
	 sid
	 pp2p
	 ifd
	 alives
	 timerFacet
      meth init(SId Handler)
	 h:=Handler
	 sid:=SId
	 pp2p:={PP2P init(UUID|pp2p|@sid
			  {self facet(pp2pDeliver:Pp2pDeliver $)})}
	 ifd:={IFD init(UUID|ifd|@sid
			{self facet(ifdCrash:IfdCrash $)})}
	 alives:={NewDictionary}
	 timerFacet:={self facet(check:Check $)}
	 {Alarm setAlarmIn(SURVIVABILITY @timerFacet)}
      end
      meth pfdMonitor(P)
	 {@pp2p pp2pSend(P monitor)}
      end
      meth Check()
	 Now={Alarm getTime($)} in
	 for P#T in {Dictionary.items @alives} do
	    if T+2*SKEW*SURVIVABILITY<Now then
	       {@h pfdCrash(P)}
	    end
	 end
	 {Alarm setAlarmIn(SURVIVABILITY @timerFacet)}
      end
      meth Pp2pDeliver(From Msg)
	 case Msg
	 of monitor then
	    {@ifd ifdMonitor(From)}
	    Monitors.(From.id):={Alarm getTime($)}+SURVIVABILITY
	    {@pp2p pp2pSend(From monitored)}
	 [] monitored then
	    @alives.(From.id)=From#{Alarm getTime($)}
	    {@h pfdAlive(From)}
	    {@pp2p pp2pSend(From keepAlive)}
	 [] keepAlive then
	    Monitors.(From.id):={Alarm getTime($)}+SURVIVABILITY
	    {@pp2p pp2pSend(From alive)}
	 [] alive then
	    @alives.(From.id):=From#{Alarm getTime($)}
	    {@pp2p pp2pSend(From keepAlive)}
	 end
      end
      meth IfdCrash(P)
	 {Dictionary.remove Monitors P.id}
      end
   end
end
fun{Process LM ?Uri}
   Comm={{LM getLayer('dist-layer:comm-interface' $)} init(Handler)}
   Alive={NewCell true}
   proc{Handler M}
      case M
      of deliver(_ _) then skip
      [] amIAlive(S) then S=@Alive
      [] iAmDead then skip
      end
   end
in
   Uri='dist-layer:process'
   class from Session
      meth init()
	 skip
      end
      meth killMe()
	 Alive:=false
      end
      meth here($)
	 {Comm thisProcess($)}
      end
      meth toText(D $)
	 {Wait D}
	 {ToAlpha {Pickle.pack D} ""}
      end
      meth fromText(A $)
	 {Pickle.unpack {FromAlpha A nil}}
      end
      meth address(Action Address Sync<=_)=M
	 {Comm M}
      end
      meth connection(Action Conn)=M
	 {Comm M}
      end
   end
end
fun{Ifd LM ?Uri}
   UUID='ifd(32f68689-d77d-443e-9fe1-7ad3f0eae972)'
   Comm={{LM getLayer('dist-layer:comm-interface' $)} init(Handler)}
   PP2P={LM getLayer('dist-layer:pp2p' $)}
   Sessions={LKDictionary.new}
   proc{Handler M}
      case M
      of deliver(From Msg) then
	 case Msg
	 of zombie(UUID(SId iAmDead)) then
	    {{Sessions condGet(SId DontCare $)} hasDied(From)}
	 [] zombie(UUID(SId rip)) then
	    {{Sessions get(SId $)} rip(From)}
	 else skip
	 end
      [] amIAlive(?S) then S=true
      [] iAmDead then
	 for S in {Sessions items($)} do
	    {S iAmDead}
	 end
      end
   end
in
   Uri='dist-layer:ifd'
   class from Session
      attr
	 h
	 sid
	 pp2p
	 toSignal
	 monitoring
      meth init(SId Handler)
	 h:=Handler
	 sid:=SId
	 pp2p:={PP2P init(UUID|@sid {self facet(pp2pDeliver:Pp2pDeliver $)})}
	 {Sessions add(@sid {self facet(hasDied:HasDied
					iAmDead:IAmDead
					rip:RIP
					$)})}
	 toSignal:={NewDictionary}
	 monitoring:={NewDictionary}
      end
      meth ifdMonitor(P)
	 {@pp2p pp2pSend(P monitor)}
      end
      meth Pp2pDeliver(From Msg)
	 case Msg
	 of monitor then
	    @toSignal.(From.id):=From
	    {@pp2p pp2pSend(From monitored)}
	 [] monitored then
	    {@h ifdMonitoring(From)}
	    @monitoring.(From.id):=unit
	 end
      end
      meth IAmDead	 
	 proc{Loop}
	    if {Not {Dictionary.isEmpty @toSignal}} then
	       for P in {Dictionary.items @toSignal} do
		  {Comm send(P zombie(UUID(@sid iAmDead)))}
	       end
	    end
	 end
      in
	 thread
	    {Loop}
	 end
      end
      meth HasDied(P)
	 if {HasFeature @monitoring P.id} then
	    {@h ifdCrash(P)}
	    {Dictionary.remove @monitoring P.id}
	    {Comm send(P zombie(UUID(rip @sid)))}
	 end
      end
      meth RIP(P)
	 {Dictionary.remove @toSignal P.id}
      end
   end
end
fun{Bep2p LM ?Uri}
   UUID='bep2p(3466cb1d-593d-484e-93f9-eeff04ae3f04)'
   proc{Handler M}
      case M
      of deliver(From Msg) then
	 case Msg
	 of UUID(SId Msg) then
	    {{Sessions condGet(SId DontCare $)} bep2pDeliver(From Msg)}
	 else skip
	 end
      [] amIAlive(?S) then
	 S=true
      [] iAmDead then
	 skip
      end
   end
   Comm={{LM getLayer('dist-layer:comm-interface' $)} init(Handler)}
   Sessions={LKDictionary.new}
in
   Uri='dist-layer:bep2p'
   class from Session
      attr
	 sid
      meth init(SId Handler)
	 sid:=SId
	 {Sessions put(SId Handler)}
      end
      meth bep2pSend(To Msg)
	 {Comm send(To UUID(@sid Msg))}
      end
   end
end
fun{Comm LM ?Uri}
   proc{GHandler M}
      case M
      of deliver(From Msg) then
	 {ForAll @Sessions proc{$ S}{S deliver(From Msg)}end}
      [] amIAlive(?S) then
	 S={All @Sessions fun{$ S}{S amIAlive($)}end}
	 if {Not S} then
	    {ForAll @Sessions proc{$ S}{S iAmDead()}end}
	 end
      end
   end
   LocalP={{LM getLayer('comm:localProcess' $)} init(GHandler)}
   Sessions={NewCell nil}
in
   Uri='dist-layer:comm-interface'
   class from Session
      attr
	 h
      meth init(Handler)
	 h:=Handler
	 (OldSessions=Sessions:=@h|OldSessions in skip)
      end
      meth send(To Msg)
	 {LocalP send(To Msg)}
      end
      meth address(Action Addr Sync<=_)
	 {LocalP address(Action Addr Sync)}
      end
      meth connection(Action Conn)
	 {LocalP connection(Action Conn)}
      end
      meth thisProcess($)
	 {LocalP thisProcess($)}
      end
   end
end
end