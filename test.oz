declare
[D DE]={Link ['distBase.ozf'
	      'distExtra.ozf'
	     ]}
{Browse D}
{Wait D}
{DE.load}

L={New D.localProcess init()}
{Browse {L getProcess($)}}
FL={L newService(pp2p() Show $)}
{Browse FL}

{FL send({L getProcess($)} hello)}
{Pickle.save {L getProcess($)}#{FL getRef($)} '/home/yjaradin/SINF2345/connect.p'}
