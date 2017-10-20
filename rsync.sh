#!/bin/bash

# Auteur : Étienne St-Amant-Audet
#          
# Date   : 27 novembre 2015
#
# Fichier : Rsync.sh
#
# Début du script

# Validation que l'utilisateur n'est pas root

if (( UID != 0 )) ; then
   echo -e "\nVous devez être root pour exécuter ce script.\n" >&2
   exit 1 
fi

ok="vrai"

# Validation du nombre de paramètres

if (( $# < 2 )) ; then
   echo -e "\nErreur, il y a moins de deux paramètres envoyés au script.\n" >&2
   ok="faux"
elif (( $# > 2 )) ; then
   echo -e "\nErreur, il y a plus de deux paramètres envoyés au script.\n" >&2
   ok="faux"
fi

if [[ $ok == "faux" ]] ; then
   echo -e "\nCe script doit recevoir deux paramètres." >&2
   echo -e "\nVous devez mettre LES paramètres en argument juste après" >&2
   echo -e "l'appel du script. Ex : $0 Utilisateur Serveur(distant)\n" >&2
   exit 1
fi

# Trouver le backup du serveur

/bin/ls -la /backup*/$2

if (( $? != 0 )) ; then
   echo -e "\nErreur, le serveur $2 n'existe pas\n" >&2
   exit 1
fi

# User existe ?

/bin/ls -la /backup*/$2/$1/homedir/public_html

if (( $? != 0 )) ; then
   echo -e "\nErreur, le user $1 n'existe pas\n" >&2
   exit 1
fi

# Validation Maven/Likuid

if [[ $2 == "maven*" ]] ; then
   serveur="$2.com"

else
   serveur="$2.likuid.com"
fi

# Rsync pour la restauration

/usr/bin/rsync -avH --rsh='ssh -p22' /backup*/$2/$1/homedir/public_html/ $serveur:/home/$1/public_html/

if (( $? != 0 )) ; then
   echo -e "\nErreur, la restauration a échouée\n" >&2
   exit 1
fi

# Copie des bases de données

/usr/bin/scp /backup*/$2/$1/mysql/$1_*.sql $serveur:/home/$1/

if (( $? != 0 )) ; then
   echo -e "\nErreur, la copie des bases de données a échouée\n" >&2
   exit 1
fi

# Changement de propriétaire du public_html

/usr/bin/ssh $server 'chown -R $1:$1 /home/$1/public_html/;chown $1:nobody /home/$1/public_html'

# Restauration des bases de données

# Fin du script

echo -e "\nLa restauration s'est terminée avec succès :)\n"
