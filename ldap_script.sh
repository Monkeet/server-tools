#!/bin/bash
#
# Auteur : Étienne St-Amant-Audet
# Date   : 14/02/2018
#
# Fichier : checkpasswdexp.sh
#
# Ce script permet de vérifier l'expiration des mots de passe LDAP. Il vérifie si les mots de passe expirent dans 60, 30, 10, 3 et 1 jour(s).
# Si le déclencheur est activé, une alerte sera envoyé aux employés concernés.

# Fortement inspiré de ce script : http://techadminblog.com/send-password-expiry-warning-openldap/

# Début du script

# L'utilisateur LDAP pour faire les requêtes

ROOTDN="cn=passwdexp,ou=dsa,dc=domain,dc=com"

# Mot de passe encrypté (base64)

ROOTPW=`echo ENCODED_STRING | openssl enc -base64 -d`

# L'âge des mots de passe (en jours)

MAXPWDAGE=365

# On vide le fichier expired.txt pour les comptes expirés

>expired.txt

# Fonction pour envoyer les mails

smail() {
   MAILID=`ldapsearch -xw $ROOTPW -D $ROOTDN -b $i mail -LLL |grep -i ^mail|awk '{print $2}'`
   if [ -n "$MAILID" ]; then
      echo -e "Bonjour,\n\nIl faut absolument que vous changiez votre mot de passe LDAP.\n\nVoici le lien pour le faire : [...] \
      \n\nLe support [...]"|  mail -s "$SUB" -S from=noreply@domain.com $MAILID
   fi
}

for i in `ldapsearch -xw $ROOTPW -D $ROOTDN -b ou=users,dc=domain,dc=com -LLL dn|awk '{print $2}'|grep uid`
   do
       USERID=`echo $i|awk -F, '($1~uid){print $1}'|awk -F= '{print $2}'`
       PWCGE=$(ldapsearch -xw $ROOTPW -D $ROOTDN -b $i -LLL pwdchangedtime|grep -i ^pwdchangedtime|awk '{print $2}'|sed 's/Z//')
       EXDTE=`echo $PWCGE |cut -c 1-8`
       EXTME=`echo $PWCGE |cut -c 9- |sed 's/.\{2\}/&:/g' |cut -c -8`
       EXSEC=`date -d "$EXDTE $EXTME" +%s`
       CDSEC=`date -u +%s`
       DIFF=`expr \( $CDSEC / 86400 \) - \( $EXSEC / 86400 \)`

       if [ "$DIFF" == `expr $MAXPWDAGE - 60` ]; then
          SUB="Votre mot de passe LDAP pour l'utilisateur $USERID expire dans 60 jours"
          echo $SUB
          smail

       elif [ "$DIFF" == `expr $MAXPWDAGE - 30` ]; then
          SUB="Votre mot de passe LDAP pour l'utilisateur $USERID expire 30 jours"
          echo $SUB 
          smail   
       elif [ "$DIFF" == `expr $MAXPWDAGE - 10` ]; then
          SUB="Votre mot de passe LDAP pour l'utilisateur $USERID expire dans 10 jours"
          echo $SUB
          smail
        elif [ "$DIFF" == `expr $MAXPWDAGE - 3` ]; then
           SUB="Votre mot de passe LDAP pour l'utilisateur $USERID expire dans 3 jours"
           smail
           echo $SUB
        elif [ "$DIFF" == `expr $MAXPWDAGE - 1` ]; then  
            SUB="Votre mot de passe LDAP pour l'utilisateur $USERID expire dans 1 jour"
            echo $SUB
            smail
        elif [ "$DIFF" == "$MAXPWDAGE" ]; then
             SUB="***Dernier Avis*** Votre mot de passe LDAP pour l'utilisateur $USERID expire aujourd'hui à $EXTME UTC"
             smail
             echo $SUB
        elif (( $DIFF > $MAXPWDAGE )) ; then
             echo $USERID >> expired.txt
        fi
        unset USERID PWCGE EXDTE EXTME EXSEC CDSEC DIFF i
   done

# Création de l'alerte Shinken correspondante

if [[ ! -s "expired.txt" ]] ; then
       output="OK- Aucun utilisateur LDAP expiré | "
       exitcode=0
elif [[ -s "expired.txt" ]] ; then
    nbligne=$(wc -l expired.txt | cut -d " " -f 1)
    if (( $nbligne <= 5  )) ; then
        output="WARNING- Quelques utilisateurs LDAP expirés ($nbligne) | "
       exitcode=1
    elif (( $nbligne > 5 )) ; then
        output="CRITICAL- Beaucoup d'utilisateurs LDAP expirés ($nbligne) | "
       exitcode=2
    else
       output="UNKOWN- | "
       exitcode=3
    fi
    
    while read line; do output="$output$line " ; done < expired.txt
fi

echo $output
exit $exitcode
