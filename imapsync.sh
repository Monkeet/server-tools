#!/bin/bash

# Auteur : Etienne St-Amant-Audet
# Date   : 28 juin 2016
#
# Fichier : imapsync.sh
#
# Ce script permet de synchroniser des mails d'un serveur A à un serveur B.
# Il créer aussi les comptes mails avec l'api de CPanel sur le serveur B avec
# le même mot de passe que celui de A. Les adresses mails et les mots de passes
# pour le transfert sont lus dans le fichier imapsync-accounts.txt du repertoire
# courant.
#
# Options     :     --host1 et --host2
#
# Dépendances : imapsync-accounts.txt && createmail.pl

# Début du script

# Validation de l'utilisateur root

if (( UID != 0 )) ; then
   echo -e "\nVous devez être root pour exécuter ce script.\n" >&2
   exit 1
fi

# Le message d'aide de la commande

helptext () {
    tput bold
    tput setaf 2
    echo "Aide pour le script imapsync:"
    echo "Synchronise et créer les comptes d'un serveur A à un serveur B"
    echo "USAGE: imapsync.sh [options]"
    echo "---------------"
    echo "Options:"
    echo "-h ou --help: Affiche l'aide et quitte le script"
    echo "--host1: Serveur A ( Serveur source )"
    echo "--host2: Serveur B ( Serveur cible )"
    echo "**Ajouter le fingerprint du serveur cible**"
    tput sgr0
    exit 0
}

# Fonction principale pour synchroniser les mails et créer les comtpes

imapsync () {

SERVERNAME=$HOSTNAME
SCRIPT_NAME="$SERVERNAME - Batch IMAP TO IMAP"
MAIL=/bin/mail;
MAIL_RECIPIENT="deadmail AT mrbuckykat.com"
LOCK_FILE="/tmp/$SERVERNAME.imapsync.lockfile"
LOGFILE="imapsync_log.txt"

#HOST1 c'est la source
HOST1=$1

#HOST2, la destination
HOST2=$2


######################################
###### Ne pas modifier le reste ######
######################################

#if [ ! -e $LOCK_FILE ]; then
#touch $LOCK_FILE
#Run core script

TIME_NOW=$(date +"%Y-%m-%d %T")

echo "" > $LOGFILE
echo "------------------------------------" >> $LOGFILE
echo "IMAPSync started - $TIME_NOW" >> $LOGFILE
echo "" >> $LOGFILE

# On crée les comptes courriels sur le serveur avant de commencer.

echo -e "\nCréation des comptes courriels sur le serveur $HOST2\n"

# On lit le mot de passe de façon sécurisée du serveur où l'on envoi les mails

echo -e "Mot de passe pour $HOST2 : \c"
stty_orig=`stty -g` # On sauvegarde les paramètres originaux du terminal
stty -echo          # On désactive l'affichage (echo)
read passwd         # On lit le mot de passe
stty $stty_orig     # On restaure les paramètres originaux du terminal
echo -e "\n"        # On passe deux lignes

/usr/bin/perl /root/imapsync/createmail.pl $HOST2 $passwd | sed 's/<[^>]\+>//g'

{ while IFS=';' read u1 p1; do
 echo ""
 echo "Synchronisation de l'adresse $u1"
TIME_NOW=$(date +"%Y-%m-%d %T")
 echo "Depart de la synchronisation de $u1"
 echo "Starting $u1 $TIME_NOW" >> $LOGFILE
if [[ $HOST1 == "imap-mail.outlook.com" || $HOST1 == "imap.outlook.com" || $HOST1 == "outlook.office365.com" ]] ; then
    /usr/bin/imapsync --host1 $HOST1 --ssl1 --user1 $u1 --password1 $p1 --host2 $HOST2 \
    --user2 $u1 --password2 $p1 --regextrans2 's/&AMk-l&AOk-ments envoy&AOk-s/Sent/' \
    --regextrans2 's/&AMk-l&AOk-ments supprim&AOk-s/Trash/' \
    --regextrans2 's/&AMk-l&AOk-ments supprim&AOk-s/Drafts/' \
    --regextrans2 's/Junk E-mail/Junk/' \
    --regextrans2 's/Courrier ind&AOk-sirable/Junk/' \
    --noauthmd5   --sep2 "."
elif [[ $HOST1 == "mail.likuid.com" ]] ; then
   /usr/bin/imapsync --host1 $HOST1 --user1 $u1 --password1 $p1 --host2 $HOST2  \
   --user2 $u1 --password2 $p1 --sep1 "/" --prefix1 "" --useheader Message-Id --noabletosearch --regextrans2 "s,Deleted Items,Trash," --regextrans2 "s,Junk E-Mail,Junk," --regextrans2 "s,Sent Items,Sent,"
else
   /usr/bin/imapsync --host1 $HOST1 --ssl1 --user1 $u1 --password1 $p1 --host2 $HOST2 --user2 $u1 --password2 $p1 --noauthmd5
fi

# V�rification

if (( $? == 0 )) ; then
 tput bold
 tput setaf 2
 echo "===== SUCCES ====" | tee -a $LOGFILE
else
 tput bold
 tput setaf 1
 echo "===== Account FAILED ====" | tee -a $LOGFILE
fi
tput sgr0
TIME_NOW=$(date +"%Y-%m-%d %T")
echo "Adresse $u1 terminée"
echo "Finished $u1 $TIME_NOW" >> $LOGFILE
echo "" >> $LOGFILE
done ; } < imapsync-accounts.txt
TIME_NOW=$(date +"%Y-%m-%d %T")
echo "" >> $LOGFILE
echo "IMAPSync Finished - $TIME_NOW" >> $LOGFILE
echo "------------------------------------" >> $LOGFILE

#End core script
#uncomment if you want a email once script is finished - useful for big syncs
#echo " IMAPSync Finished" | $MAIL -s "[$SCRIPT_NAME] Finshed" $MAIL_RECIPIENT
#rm -f $LOCK_FILE

#else
#       TIME_NOW=$(date +"%Y-%m-%d %T")
#       #echo "$SCRIPT_NAME at $TIME_NOW is still running" | $MAIL -s "[$SCRIPT_NAME] !!WARNING!! still running" $MAIL_RECIPIENT
#       echo "$SCRIPT_NAME at $TIME_NOW is still running"
#fi

#Fini
    tput bold
    tput setaf 3
        echo ""
    echo "Fin du script imapsync!"
  echo "----------------------------------------------------------------------------------"
  printf "\n\n"
    tput sgr0

  return 0

}

# Fonction principale avec le switch pour les options

case "$1" in

    -h) helptext
  ;;
    --help) helptext
  ;;
        --host1)

      case "$3" in

    --host2) imapsync "$2" "$4"
        ;;
    *) tput bold
           tput setaf 1
       echo "Option invalide!"
       helptext
       ;;
  esac
  ;;
  *)
       tput bold
       tput setaf 1
       echo "Option invalide!"
       helptext
esac
