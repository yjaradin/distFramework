%Example ping-pong application
functor
import
   DistFramework(layerManager:LM
		 session:Session
		 version:DistVersion
		 pp2p:PP2P_F
		 process:Process_F)
   Application
   System
define
   true=DistVersion==2 %Assert it's the right version of the framework
   fun{MyApp_F LM ?Uri}
      PP2P={LM getLayer('dist-layer:pp2p' $)}
   in
      Uri='app-layer:ping-pong'
      class from Session
	 attr pp2p
	 meth init()
	    pp2p:={PP2P init([test] {self facet($ pp2pDeliver:PP2P_Deliver)})}
	 end
	 meth start(Dest Count)
	    {@pp2p pp2pSend(Dest ping(Count))}
	 end
	 meth PP2P_Deliver(From Msg)
	    {System.show pp2pDeliver(From Msg)}
	    case Msg
	    of ping(N) andthen N>0 then
	       {@pp2p pp2pSend(From pong(N-1))}
	    [] ping(0) then
	       {System.showInfo "She wins"}
	    [] pong(N) andthen N>0 then
	       {@pp2p pp2pSend(From ping(N-1))}
	    [] pong(0) then
	       {System.showInfo "He wins"}
	    end
	 end
      end
   end
   {LM init(socket)}
   {LM introduceLayer(PP2P_F)}
   {LM introduceLayer(Process_F)}
   {LM introduceLayer(MyApp_F)}

   Process={{LM getLayer('dist-layer:process' $)} init()}
   TheApp={{LM getLayer('app-layer:ping-pong' $)} init()}
   
   Args={Application.getArgs record(count(single type:int default:100)
				    dest(single type:string))}
   if {HasFeature Args dest} then
      {TheApp start({Process fromText(Args.dest $)} Args.count)}
   else
      {System.showInfo "The destination for this process is:"}
      {System.showInfo {Process toText({Process here($)} $)}}
   end
end