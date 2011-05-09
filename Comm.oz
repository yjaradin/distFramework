functor
import
   DistFramework(session:Session)
export
   LocalProcess
   RemoteProcess
   Router
define
fun{RemoteProcess LM ?Uri}
   Uri='comm:remoteProcess'
   class from Session
      attr
	 myRef
	 h
	 connections
	 connecting
      meth init(Ref Handler)
	 connections:=nil
	 connecting:=false
	 myRef:=Ref
	 h:=Handler
      end
      meth Merge(Ref)
	 true=Ref.id==@myRef.id
	 if Ref.version>@myRef.version then
	    connecting:=false
	    myRef:=Ref
	 end
      end
      meth msg(From To Msg)
	 true=To.id==@myRef.id
	 {self Merge(To)}
	 {self EnsureConn()}
	 {ForAll @connections proc{$ C}{C send(From To Msg)}end}
      end
      meth thisProcess($)
	 @myRef
      end
      meth connection(Action Conn Sync<=_)
	 true={Conn getProcess($)}.id==@myRef.id
	 {self Merge({Conn getProcess($)})}
	 connections:=
	 case Action
	 of add then
	    {Conn reg({self facet(deliver:Deliver connection:connection $)})}
	    Conn|@connections
	 [] remove then
	    {Filter @connections
	     fun{$ C} C\=Conn end}
	 end
	 connecting:=false
	 Sync=unit
	 {self EnsureConn()}
      end
      meth Deliver(From To Msg)
	 true=From.id==@myRef.id
	 {@h msg(From To Msg)}
      end
      meth EnsureConn()
	 if @connections==nil andthen {Not @connecting} then
	    connecting:=true
	    for A in @myRef.addresses do
	       _={{LM getLayer(A.layer $)} init(A @this)}
	    end
	    thread {Delay 3000} connecting:=false end %make sure we will eventualy retry
	 end
      end
   end
end
fun{Router LM ?Uri}
   Remote={LM getLayer('comm:remoteProcess' $)}   
in
   Uri='comm:router'
   class from Session
      attr
	 h
	 sites
	 msgP
      meth init(LocId LocSite Handler)
	 this:=self % Makes the object passive
	 proc{Loop Xs}
	    case Xs
	    of sync(S)|Xr then
	       {Wait Xr}
	       if S then
		  {Loop Xr}
	       end
	    [] msg(From To Content)|Xr then
	       {@this Msg(From To Content)}
	       {Loop Xr}
	    end
	 end
	 fun lazy{MkSync}
	    {Send @msgP sync({MkSync})}
	    {@h amIAlive($)}
	 end
      in
	 sites:={NewDictionary}
	 @sites.LocId:=LocSite
	 h:=Handler
	 msgP:={NewPort thread {Loop} end}
	 {Wait {MkSync}}
      end
      meth msg(From To Content)
	 case Content
	 of zombie(_) then
	    {@this Msg(From To Content)}
	 else
	    {Send @msgP msg(From To Content)}
	 end
      end
      meth EnsureSite(Dest)
	 if {Not {HasFeature @sites Dest.id}} then %This condition is just for the fast-path
	    Old New in
	    {Dictionary.condExchange @sites Dest.id unit Old New}
	    case Old
	    of unit then 
	       New={Remote init(Dest @this)}
	    else
	       New=Old
	    end
	 end
      end
      meth Msg(From To Content)
	 {self EnsureSite(To)}
	 {@sites.(To.id) msg(From To Content)}
      end
      meth connection(Action Conn Sync<=_)
	 {self EnsureSite({Conn getProcess($)})}
	 {@sites.({Conn getProcess($)}.id) connection(Action Conn Sync)}
      end
   end
end
fun{LocalProcess LM ?Uri}
   Router={LM getLayer('comm:router' $)}
in
   Uri='comm:localProcess'
   class from Session
      attr
	 myRef
	 h
	 router
      meth init(Handler)
	 myRef:=site(id:{NewName} version:0 addresses:nil)
	 h:=Handler
	 router:={Router init(@myRef.id
			      {self facet(msg:Deliver $)}
			      {self facet(amIAlive:AmIAlive $)}
			     )}
      end
      meth thisProcess($)
	 @myRef
      end
      meth send(To Msg)
	 {@router msg(@myRef To Msg)}
      end
      meth Deliver(From To Msg)
	 true=To.id==@myRef.id
	 {@h deliver(From Msg)}
      end
      meth AmIAlive(?S)
	 {@h amIAlive(S)}
      end
      meth connection(...)=C
	 {@router C}
      end
      meth address(Action Address Sync<=_)
	 NewAddresses=
	 case Action
	 of add then
	    Address|@myRef.addresses
	 [] remove then
	    {Filter @myRef.addresses
	     fun{$ A}
		A.id\=Address.id
	     end}
	 end
      in
	 myRef:=site(id:@myRef.id
		     version:@myRef.version+1
		     addresses:NewAddresses)
	 Sync=unit
      end
   end
end
end