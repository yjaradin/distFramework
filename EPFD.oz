functor
export
   Epfd
define
   fun{Epfd LM ?Uri}
      PP2P={LM getLayer('dist-layer:pp2p' $)}
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
	    oldMonitored:={NewDictionary}
	    monitored:={NewDictionary}
	    monitoring:={NewDictionary}
	    {@sendAlarm setAlarmIn(SEND_DELAY unit)}
	    {@checkAlarm setAlarmIn(CHECK_DELAY unit)}
	 end
	 meth monitor(Remote)
	    @monitored.Remote:=false
	    @oldMonitored.Remote:=unit
	    {@pp2p pp2pSend(Remote monitor())}
	 end
	 meth Deliver(From Msg)
	    case Msg
	    of monitor() then
	       @monitoring.From:=unit
	    [] imAlive() then
	       @monitored.From:=true
	    end
	 end
	 meth Check(_)
	    for X in {Dictionary.keys @monitored} do
	       if @oldMonitored.X \= @monitored.X then
		  if @monitored.X then
		     {@h crash(X)}
		  else
		     {@h alive(X)}
		  end
		  @oldMonitored.X:=@monitored.X
	       end
	       @monitored.X:=false
	    end
	    {@checkAlarm setAlarmIn(SEND_DELAY unit)}
	 end
	 meth Send(_)
	    for X in {Dictionary.keys @monitoring} do
	       {@pp2p pp2pSend(X imAlive)}
	    end
	    {@sendAlarm setAlarmIn(SEND_DELAY unit)}
	 end
      end
   end
end
