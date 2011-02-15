functor
import
   Pickle(pack:Pack unpack:Unpack)
   Connection
   Open
   OS
   SerializationUtils(toAlpha:ToAlpha
		      completeTokens:CompleteTokens)
   DistFramework(session:Session)
export
   InternalLayerPort
   InternalLayerSocket
define
   fun{InternalLayerPort LM ?Uri}
      Tail
      ThisDest={Port.new {Cell.new $ Tail}}
      thread
	 proc{Loop}
	    Tail:=@Tail.2
	    {Loop}
	 end in
	 {Loop}
      end
   in
      Uri='dist-base:internals'
      class from Session
	 meth init()
	    skip
	 end
	 meth thisDest($)
	    ThisDest
	 end
	 meth serializeDest(D $)
	    {Connection.offerMany D}
	 end
	 meth deserializeDest(D $)
	    {Connection.take D}
	 end
	 meth send(D M)
	    {Port.send D iMsg(ThisDest M)}
	 end
	 meth receive($)
	    @Tail
	 end
      end
   end
   fun{InternalLayerSocket LM ?Uri}
      fun{BetterIP IP1 IP2}
	 for
	    P in ["127." "169.254." "192.168."
		  "172.16." "172.17." "172.18." "172.19."
		  "172.20." "172.21." "172.22." "172.23."
		  "172.24." "172.25." "172.26." "172.27."
		  "172.28." "172.29." "172.30." "172.31."
		  "10."]
	    return:R
	 do
	    if {List.isPrefix P IP1} then {R false} end
	    if {List.isPrefix P IP2} then {R true} end
	 end
      end
      fun{GetHost}
	 IPs={Append
	      {OS.getHostByName "localhost"}.addrList
	      {OS.getHostByName {OS.uName}.nodename}.addrList
	     } in
	 {List.sort IPs BetterIP}.1
      end
      Tail
      RPort={Port.new {Cell.new $ Tail}}
      thread
	 proc{Loop}
	    Tail:=@Tail.2
	    {Loop}
	 end in
	 {Loop}
      end
      ServSocket={New Open.socket init()}
      TCPPort={ServSocket bind(port:$)}
      ThisDest=site(id:{NewName} host:{GetHost} port:TCPPort)
      {ServSocket listen()}
      thread
	 proc{Loop}
	    Bytes Blobs Msgs
	    ThatSocket={ServSocket
			accept(accepted:$
			       acceptClass:Open.socket)}
	 in
	    thread
	       %%{Browse bytes(Bytes)}
	       {ThatSocket read(list:Bytes size:all)}
	    end
	    thread
	       %%{Browse blobs(Blobs)}
	       Blobs={CompleteTokens Bytes [&,]}
	    end
	    thread
	       %%{Browse msgs(Msgs)}
	       Msgs={Map Blobs Unpack}
	    end
	    thread
	       Src=Msgs.1 in
	       for M in Msgs.2 do
		  {Port.send RPort iMsg(Src M)}
	       end
	    end
	    {Loop}
	 end
      in
	 {Loop}
      end
      Connections={Dictionary.new}
   in
      Uri='dist-base:internals'
      class from Session
	 meth init()
	    skip
	 end
	 meth thisDest($)
	    ThisDest
	 end
	 meth serializeDest(D $)
	    {Pickle.pack D}
	 end
	 meth deserializeDest(D $)
	    {Pickle.unpack D}
	 end
	 meth send(D M)
	    P in
	    case {Dictionary.condExchange
		  Connections D.id unit $ P}
	    of unit then
	       ThatSocket={New Open.socket client(host:D.host
						  port:D.port)}
	    in
	       {ThatSocket
		write(vs:{ToAlpha {Pack ThisDest} ","})}
	       P={Port.new
		  thread
		     for M in $ do
			%%{Browse msg(M)}
			{ThatSocket
			 write(vs:{ToAlpha {Pack M} ","})}
		     end
		  end}
	    [] O then
	       P=O
	    end
	    {Port.send P M}
	 end
	 meth receive($)
	    @Tail
	 end
      end
   end   
end