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

HOST=$1

echo -e "\nCréation des comptes courriels sur le serveur $HOST\n"

# On lit le mot de passe de façon sécurisée du serveur où l'on envoi les mails

echo -e "Mot de passe pour $HOST : \c"
stty_orig=`stty -g` # On sauvegarde les paramètres originaux du terminal
stty -echo          # On désactive l'affichage (echo)
read passwd         # On lit le mot de passe
stty $stty_orig     # On restaure les paramètres originaux du terminal
echo -e "\n"        # On passe deux lignes

/usr/bin/perl /root/imapsync/createmail.pl $HOST $passwd | sed 's/<[^>]\+>//g'

}

# Fonction principale avec le switch pour les options

imapsync $1
