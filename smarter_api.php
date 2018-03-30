<?php

# NOTE: Ce script prend en paramètre le nom du domaine choisi
# Mettre les informations de votre serveur smartermail ici


$DOMAIN=
$USER=
$PASS=

$soapClient = new SoapClient( "http://$DOMAIN/Services/svcUserAdmin.asmx?WSDL", array( 'trace' => true ) );
	
$soap_user_params = array
(
   'AuthUserName'  => $USER,
   'AuthPassword'  => $PASS,
   'DomainName'    => $argv[1]
);
	
try {

	$info = $soapClient->__soapCall("GetUsers", array( 'parameters' => $soap_user_params ) );

	foreach($info->GetUsersResult->Users->UserInfo as $k => $cur) {
		if (!preg_match('/^_/', $cur->UserName)) {
    		   echo $cur->UserName.";".$cur->Password;
    		   echo "\n";
		}
	 }
} 

catch (SoapFault $fault) {
	printf("Error %s: %s\n", $fault->faultcode, $fault->faultstring);
}
?>
