#!/bin/bash
#
# Auteur : Etienne St-Amant-Audet
# Date   : 17 mars 2017
#
# Fichier : deploy
#
# Ce script permet de changer les permissions des utilisateurs sur le serveur.
# Il change toutes les permissions des dossiers en 755 et des fichiers en 644
# qui se trouvent en dessous du public_html.

# Exeptions : *.cgi *.pl cgi-bin/* et lib/atos/bin/* --> 755
# Emplacement : /root/bin

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
    echo "-v: Mode volubile"
    echo "-all: Parcours tous les utilisateurs CPanel"
    echo "--account ou -a: Specifie un compte CPanel"
    tput sgr0
    exit 0
}

deploy () {

compte=$1
serveur=
repertoire=
utilisateur=
mdp=''
url=''

rm -rf /home/$1/public_html
cd /home/$1
wget --no-parent -m --cut-dirs=1 ftp://$serveur/$repertoire/ --ftp-user=$utilisateur --password=$mdp
mv /home/$1/$serveur /home/$1/public_html
chown -R $1:$1 /home/$1/public_html
chown $1:nobody /home/$1/public_html

cd /root/phoenix

# Connexion FTP pour uploader le script php

ftp -inv $serveur << EOF

# Call 2. Here the login credentials are supplied by calling the variables.

user $utilisateur $mdp

# Call 3. Here you will change to the directory where you want to put or get
cd /$repertoire

# Call4.  Here you will tell FTP to put or get the file.
put aaa-sql-backup.php

# End FTP Connection
bye

EOF

#wget --method=PUT grosfichier.txt ftp://aaa2likuid:zxcv1234!!!!@198.50.142.4/public_html/export-ftp/
ssh we-are.likuid.com -p 50666 "curl $url/aaa-sql-backup.php"
sleep 10
wget ftp://$serveur/$repertoire/db-backup.sql --ftp-user=$utilisateur --password=$mdp

#Delete backup from server

ftp -inv $serveur << EOF

# Call 2. Here the login credentials are supplied by calling the variables.

user $utilisateur $mdp

# Call 3. Here you will change to the directory where you want to put or get
cd /public_html

# Call4.  Here you will tell FTP to put or get the file.
delete db-backup.sql
delete aaa-sql-backup.php
# End FTP Connection
bye

EOF

wp='_wp'
db_name=$compte$wp
db_pass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9-_!@#$%^&*()_+{}|:<>?=' | fold -w 10 | grep -i '[!@#$%^&*()_+{}|:<>?=]' | head -n 1)

# CreateDB
cpapi2 --user=$compte MysqlFE createdb db=$db_name

#Create User_DB
uapi --user=$compte Mysql create_user name=$db_name password=$db_pass

#Set privileges
uapi --user=$compte Mysql set_privileges_on_database user=$db_name database=$db_name privileges=ALL

# Modification du charset du dump
bash iconv.sh

#Import db
mysql $db_name < db-backup.sql

# Change wp-config file

sed -i "s|define('DB_NAME', .*);|define('DB_NAME', '$db_name');|g" /home/$compte/public_html/wp-config.php
sed -i "s|define('DB_USER', .*);|define('DB_USER', '$db_name');|g" /home/$compte/public_html/wp-config.php
sed -i "s|define('DB_PASSWORD', .*);|define('DB_PASSWORD', '$db_pass');|g" /home/$compte/public_html/wp-config.php
sed -i "s|define('DB_HOST', .*);|define('DB_HOST', 'localhost');|g" /home/$compte/public_html/wp-config.php

}

# Validation du nombre de parametres

if (( $# != 2 )) ; then
      echo -e "\nErreur, cette fonction doit recevoir le bon nombre de parametres." >&2
      helptext
      exit 1
fi

# Validation de l'utilisateur CPanel

if ! id "$2" >/dev/null 2>&1 ; then
    tput bold
    tput setaf 1
    echo "Compte CPanel Invalide"
    tput sgr0
    exit 0
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
      echo "Option Invalide!"
      helptext
   ;; 
esac

deploy "$2"
#case "$3" in
#
#   -a) deploy "$3"
#    ;;
#    *) tput bold
#           tput setaf 1
#       echo "Option Invalide!"
#       helptext
#      ;;
#esac 
