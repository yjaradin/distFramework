declare
[D DE]={Link ['/Users/matthieusieben/Documents/UCL/INGI21MS/Q2/SINF2345/project/distFramework/distBase.ozf'
	      '/Users/matthieusieben/Documents/UCL/INGI21MS/Q2/SINF2345/project/distFramework/distExtra.ozf'
	     ]}
{Browse D}
{Wait D}
{DE.load}

L={New D.localProcess init()}
{Browse {L getProcess($)}}
FL={L newService(pp2p() Show $)}
{Browse FL}

{FL send({L getProcess($)} hello)}
{Pickle.save {L getProcess($)}#{FL getRef($)} '/Users/matthieusieben/Documents/UCL/INGI21MS/Q2/SINF2345/project/distFramework/connect.p'}

{FL halt}