functor
import
   DistFramework(session:Session)
export
   Epfd
define
   fun{Epfd LM ?Uri}
      PP2P={LM getLayer('dist-layer:pp2p' $)}
      BEP2P={LM getLayer('dist-layer:bep2p' $)}
      Alarm={LM getLayer('dist-layer:alarm' $)}
      UUID='epfd(8525f024-6543-4108-abb8-2621617504a9)'
      SEND_DELAY=1000
      CHECK_DELAY=5000
   in
      Uri='dist-layer:epfd'
      class from Session
	 attr
	    sendAlarm
	    checkAlarm
	    pp2p
	    bep2p
	    h
	    oldMonitored
	    monitored
	    monitoring
	 meth init(SId Handler)
	    h:=Handler
	    sendAlarm:={Alarm init(UUID|sendAlarm|SId
				   {self facet(alarm:Send $)})}
	    checkAlarm:={Alarm init(UUID|checkAlarm|SId
				    {self facet(alarm:Check $)})}
	    pp2p:={PP2P init(UUID|pp2p|SId {self facet(pp2pDeliver:Deliver $)})}
	    bep2p:={BEP2P init(UUID|bep2p|SId {self facet(bep2pDeliver:Deliver $)})}
	    oldMonitored:={NewDictionary}
	    monitored:={NewDictionary}
	    monitoring:={NewDictionary}
	    {@sendAlarm setAlarmIn(SEND_DELAY unit)}
	    {@checkAlarm setAlarmIn(CHECK_DELAY unit)}
	 end
	 meth monitor(Remote)
	    @monitored.(Remote.id):=false#Remote
	    @oldMonitored.(Remote.id):=unit#Remote
	    {@pp2p pp2pSend(Remote monitor())}
	 end
	 meth Deliver(From Msg)
	    case Msg
	    of monitor() then
	       @monitoring.(From.id):=From
	    [] imAlive() then
	       @monitored.(From.id):=true#From
	    end
	 end
	 meth Check(_)
	    for X in {Dictionary.keys @monitored} do
	       if @oldMonitored.X.1 \= @monitored.X.1 then
		  if @monitored.X.1 then
		     {@h alive(@monitored.X.2)}
		  else
		     {@h crash(@monitored.X.2)}
		  end
		  @oldMonitored.X:=@monitored.X
	       end
	       @monitored.X:=false#(@monitored.X.2)
	    end
	    {@checkAlarm setAlarmIn(CHECK_DELAY unit)}
	 end
	 meth Send(_)
	    for X in {Dictionary.items @monitoring} do
	       {@bep2p bep2pSend(X imAlive)}
	    end
	    {@sendAlarm setAlarmIn(SEND_DELAY unit)}
	 end
      end
   end
end
