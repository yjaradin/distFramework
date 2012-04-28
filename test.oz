declare
Dir='/Users/matthieusieben/Desktop/distFramework/'
[D DE]={Link [Dir#'distBase.ozf' Dir#'distExtra.ozf']}
{Browse D}
{Wait D}
{DE.load}

L={New D.localProcess init()}
{Browse {L getProcess($)}}
FL={L newService(pp2p() Show $)}
{Browse FL}

{FL send({L getProcess($)} hello)}
{Pickle.save {L getProcess($)}#{FL getRef($)} Dir#'connect.p'}

{FL halt}