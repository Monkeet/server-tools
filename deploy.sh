#!/bin/bash
#
# Auteur : Etienne St-Amant-Audet
# Date   : 21 novembre 2017
#
# Fichier : deploy.sh
#
# Ce script permet de transférer un site web d'un serveur A vers le serveur courant. Celui-ci doit avoir 
# une license valide de cPanel et le module soap de php pour que l'api smartermail fonctionne. Par défaut,
# le site est transféré et la base de données aussi à condition que le site utilise un CMS parmis les suivants :
# Wordpress, Joomla, Prestashop et Drupal. Si le site est sur le serveur www12 (helm), les mails seront créés et 
# transférés automatiquement. Sinon, il faudra créer le fichier imapsync-accounts.txt et le remplir avec les bonnes
# coordonnées. Si c'est un site qui n'utilise pas de CMS, il faudra transférer la base de données manuellement.
#

# Début du script

# Validation de l'utilisateur root

if (( UID != 0 )) ; then
   echo -e "\nVous devez être root pour exécuter ce script.\n" >&2
   exit 1
fi

# Aide de la commande

helptext () {
    tput bold
    tput setaf 2
    echo "Aide du script deploy:"
    echo "Transfert un site web complet en FTP"
    echo "USAGE: deploy [options] -a utilisateur_cpanel"
    echo "-------"
    echo "Options:"
    echo "-h ou --help: affiche l'aide et quitte le script"
    echo "--account ou -a: Specifie un compte CPanel"
    tput sgr0
    exit 0
}

deploy () {

# Validation de l'utilisateur CPanel

if ! id "$1" >/dev/null 2>&1 ; then
    tput bold
    tput setaf 1
    echo "Compte CPanel Invalide"
    tput sgr0
    exit 1
fi

LOCK_FILE=".phoenix.lock"

####### Paramètres à modifier #######

compte=$1

mailsrv=
serveur=
repertoire=wwwroot
domaine=
utilisateur=
mdp=''
url=''
replocal=
# ex : /wp

######################################

tput setaf 3
tput bold
echo "
							           /|_
    								  /   |_
                ____            _      _                         /     /
               |  _ \ _ __ ___ (_) ___| |_                      /      >
               | |_) | '__/ _ \| |/ _ \ __|                    (      >   
               |  __/| | | (_) | |  __/ |_                    /      /
               |_|   |_|  \___// |\___|\__|                  /     /  
                             |__/                           /      /
                                                         __/      \_____ 
            ____  _                      _              /'             |
           |  _ \| |__   ___  ___  _ __ (_)_  __         /     /-\     /
           | |_) | '_ \ / _ \/ _ \| '_ \| \ \/ /        /      /  \--/
           |  __/| | | |  __/ (_) | | | | |>  <        /     /
           |_|   |_| |_|\___|\___/|_| |_|_/_/\_\      /      / 
                                                     (      >
                                                    /      >
                                                   /     _|
                                                  /  __/
                                                 /_/
"
tput sgr0

# LOCKFILE

if [ ! -e $LOCK_FILE ]; then
   touch $LOCK_FILE
else
   tput bold
   tput setaf 1
   echo -e "\nErreur, il y a déjà un transfert en cours !\n" >&2
   tput sgr0
   exit 1  
fi

# Confirmation

read -r -p "Êtes-vous sûr d'avoir accès aux DNS du domaine $domaine? [O/n] " response
case "$response" in
    [OoyY][uUeE][IisS]|[oOyY]) 
        ;;
    *)
	rm -f $LOCK_FILE
        exit 1
        ;;
esac

cd /home/$1/public_html$replocal

# Mirroir FTP

echo -e "\nCopie des fichiers en cours.....\n"

wget --no-parent -m --cut-dirs=1 ftp://$serveur/$repertoire/ --ftp-user=$utilisateur --password=$mdp &> /dev/null
# lftp -u $utilisateur,$mdp -e 'mirror ftp://$serveur/$repertoire .' $serveur

if (( $? != 0 )) ; then
   tput bold
   tput setaf 1
   echo -e "\nErreur, la copie des fichiers a échouée\n" >&2
   tput sgr0
   rm -f $LOCK_FILE
   exit 1
fi

# Changement des permissions

echo -e "\nChangement des permissions.....\n"

mv /home/$1/public_html$replocal/$serveur/* /home/$1/public_html$replocal &> /dev/null
chown -R $1:$1 /home/$1/public_html$replocal &> /dev/null
chown $1:nobody /home/$1/public_html$replocal &> /dev/null
rm -rf $serveur &> /dev/null

if (( $? != 0 )) ; then
   tput bold
   tput setaf 1
   echo -e "\nErreur, le changement des permissions a échoué !\n" >&2
   tput sgr0
   rm -f $LOCK_FILE
   exit 1
fi

cd /root/phoenix

# Imapsync

echo -e "\nSynchronisation des emails.....\n"

# On rempli le fichier imapsync-accounts.txt ou on prend lui fourni par défaut

if  [[ $(php smarter_api.php $domaine) ]]; then
   php smarter_api.php $domaine > imapsync-accounts.txt
fi

# Si le fichier imapsync-accounts.txt n'est pas vide, on sync!

if [[ -s imapsync-accounts.txt ]] ; then
   # Modification du password strength temporaire
   whmapi1 setminimumpasswordstrengths default=0 &> /dev/null

   bash imapsync.sh --host1 $mailsrv --host2 localhost &> /dev/null

   if (( $? != 0 )) ; then
      tput bold
      tput setaf 1
      echo -e "\nErreur, le transfert des courriels a échoué ! \n"
      tput sgr0
   fi

   if [[ $(cat imapsync_log.txt | grep FAILED) ]] ; then
      tput bold
      tput setaf 1
      echo -e "\nAttention, certains transferts de courriels n'ont pas réussi ! "
      echo -e "Vérifiez le fichier imapsync_logs.txt et LOG_imapsync pour plus de détails.\n" >&2
      tput sgr0
   fi

   # Vider le fichier imapsync-accounts.txt
   >imapsync-accounts.txt
   # Remise du password strength par défaut
   whmapi1 setminimumpasswordstrengths default=65 &> /dev/null
fi

# Si c'est un Wordpress

wget ftp://$serveur/$repertoire/wp-config.php --ftp-user=$utilisateur --password=$mdp &> /dev/null

# Si c'est un Joomla

# Si c'est un Drupal

# Si c'est un Prestashop

if (( $? != 0 )) ; then
   tput bold
   tput setaf 2
   echo -e "\nTransfert terminé avec succès! NOTE : Le site n'utilise pas de CMS.\n" 
   tput sgr0	
   rm -f $LOCK_FILE
   exit 0
fi

rm -f wp-config.php

# Transfert de la base de données

echo -e "\nTransfert de la base de données.....\n"

# Connexion FTP pour uploader le script php

ftp -inv $serveur &> /dev/null << EOF

# Call 2. Here the login credentials are supplied by calling the variables.

user $utilisateur $mdp

# Call 3. Here you will change to the directory where you want to put or get
cd $repertoire

# Call4.  Here you will tell FTP to put or get the file.
put aaa-sql-backup.php

# End FTP Connection
bye

EOF

# Execution du script php à distance

curl $url/aaa-sql-backup.php &> /dev/null

# Délai pour effectuer le dump de la BD

sleep 10

# Téléchargement du dump de la base de données

wget ftp://$serveur/$repertoire/db-backup.sql --ftp-user=$utilisateur --password=$mdp &> /dev/null

# Supression du dump de la BD sur le serveur distant

ftp -inv $serveur &> /dev/null << EOF

# Call 2. Here the login credentials are supplied by calling the variables.

user $utilisateur $mdp

# Call 3. Here you will change to the directory where you want to put or get
cd /$repertoire

# Call4.  Here you will tell FTP to put or get the file.
delete db-backup.sql
delete aaa-sql-backup.php
# End FTP Connection
bye

EOF

# Informations de connexion à la base de données

wp='_wp'
db_name=$compte$wp
db_pass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9-_!@$%^&*()_+{}|:<>?=' | fold -w 10 | grep -i '[!@$%^&*()_+{}|:<>?=]' | head -n 1)

# Supression de la BD
cpapi2 --user=$compte MysqlFE deletedb db=$db_name &> /dev/null

# Supression de l'utilisateur de la BD
uapi --user=$compte Mysql delete_user name=$db_name password=$db_pass &> /dev/null

# Création de la base de données
cpapi2 --user=$compte MysqlFE createdb db=$db_name &> /dev/null

# Création de l'utilisateur de la base de données
uapi --user=$compte Mysql create_user name=$db_name password=$db_pass &> /dev/null

# Attribution des privilèges
uapi --user=$compte Mysql set_privileges_on_database user=$db_name database=$db_name privileges=ALL &> /dev/null

# Modification du charset du dump (s'il y a lieu)

if [[ $(file -i db-backup.sql | cut -d " " -f 3) == "charset=windows-1252" ]] ; then
	bash iconv.sh &> /dev/null
fi

# Importation de la base de données
mysql $db_name < db-backup.sql &> /dev/null
rm -f db-backup.sql

# Ajustements dans le wp-config.php

sed -i "s|define('DB_NAME', .*);|define('DB_NAME', '$db_name');|g" /home/$compte/public_html$replocal/wp-config.php &> /dev/null
sed -i "s|define('DB_USER', .*);|define('DB_USER', '$db_name');|g" /home/$compte/public_html$replocal/wp-config.php &> /dev/null
sed -i "s|define('DB_PASSWORD', .*);|define('DB_PASSWORD', '$db_pass');|g" /home/$compte/public_html$replocal/wp-config.php &> /dev/null
sed -i "s|define('DB_HOST', .*);|define('DB_HOST', 'localhost');|g" /home/$compte/public_html$replocal/wp-config.php &> /dev/null

# Vérification des erreurs

if (( $? != 0 )) ; then
   tput bold
   tput setaf 1
   echo -e "\nErreur, l'ajustement du wp-config.php a échoué!\n" >&2
   tput sgr0
   rm -f $LOCK_FILE
   exit 1
fi

# Transfert Terminé

tput bold
tput setaf 2
echo -e "\nTransfert terminé avec succès ! \n"
tput sgr0
rm -f $LOCK_FILE

}

# Validation du nombre de paramètres

if (( $# != 2 )) ; then
      tput bold
      tput setaf 1
      echo -e "\nErreur, ce script doit recevoir le bon nombre de paramètres!\n" >&2
      helptext
      exit 1
fi


# Menu pour valider les options envoyés au script

case "$1" in

   -h) helptext
   ;;
   --help) helptext
   ;;
   -a) compte=$2
   ;;
   *) tput bold
      tput setaf 1
      echo -e "\nOption Invalide!\n"
      helptext
   ;; 
esac

deploy "$2"
