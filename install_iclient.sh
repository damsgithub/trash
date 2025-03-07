#!/bin/bash
#              install_iclient.sh
#
#                  -----------------------------
#                Instant Client Installation Oracle
#                        for Common Bundle
#                  -----------------------------
#
#==========================================================================================
#
# tar -cvhf /liv/LINUX/TAR_ORACLE/PA-ORA-I192300-RDG00R00C01.tar . --exclude='./install_iclient19c.sh_______OLD*' .   # SPECIFIC CLIENT
#       (-h    : replace links with real files)
#       (no -j : because contains already compresed files)
#
# Exemple avec exclude :  tar -cvhf ../TAR_ORACLE/PA-ORA-I192300-RDG00R00C01.tar --exclude='./install_iclientToto.sh' .
#==========================================================================================
#
# Historique:
#
# 
# 2024/09/10 KKH  v1.0
#              * Version "release" initiale
#              * Correction: prise en compte de numeros de version mineure de l'OS a 2 chiffres (ex: RH 8.10)

# 2024/07/19 KKH  v0.5
#              * Les "alternatives" (ksh) ne sont plus modifiees
#              * Quantite de rpms installes fortement reduite
#              * On ne change plus les parametres kernel
#              * Le user "oracle" est maintenant cree avec bash comme shell per default. 
#              * Nouveau parametre: -k pour demander a utiliser ksh comme shell lors de la creation du user "oracle"
#
# 2024/07/09 KKH  v0.4
#              * Ajout du repo "standard" pour les RH7.1
#
# 2024/07/05 KKH v0.3
#              * Correction des conditions de sortie de kit2_volumes() pour l'etape 9a
#
#  2024/07/03  KKH v0.2
#              * Ajout de la gestion de RH9
#
# 2024/07/27   KKH v0.1
#              * Version initiale:
#                   Script install_iclient.sh generique pour tous les instant clients
#                   La configuration pour une version de client et OS se fait dans "env_install_iclient.sh"



     SCRIPT_VERSION="1.0"
     DEBUG_LEVEL=0
     SCRIPT_NAME=$( basename $0 )
     SCRIPT_NAME_LONG="Instant Client Installer"
     
     SCRIPT_ENV_FILENAME="env_install_iclient.sh"


     #  Pour la suite du code, rechercher "MAIN"

#------------------------------------------------------------------------------

# Codes d'erreur
RET_OK=0
RET_KO=1
RET_STEP_ABORTED=2
# erreurs de config
RET_NO_RPMS=20
RET_NO_ORAHOME=21
RET_NO_ORACLE_HOME=22
RET_NO_CLIENT_VERSION=23
RET_NO_RPM_FOR_OS=24
# erreurs d'execution
RET_ERROR_UNTAR=50
RET_ERROR_MKDIR=51
RET_WRONG_OS=52
RET_MUST_BE_ROOT=53
RET_MUST_BE_IN_STAGE=54
RET_WRONG_STEP=55
RET_CANNOT_WRITE_TRACE=56
RET_USE_VERSIONED_SCRIPT=57

#------------------------------------------------------------------------------

show_vars()
{

     if [[ $DEBUG_LEVEL > 0 ]]; then
          printf "\n"
          printf "%-20s %s\n" "DEBUG_LEVEL" $DEBUG_LEVEL
     fi
     printf "\n"
     printf "%-20s %s\n" "VERSMAJ" $VERSMAJ
     printf "%-20s %s\n" "VERSMAJ" $VERSMIN
     printf "%-20s %s\n" "VERSNUM" $VERSNUM
     printf "%-20s %s\n" "VERSNUM_LONG" $VERSNUM_LONG
     printf "%-20s %s\n" "VERSDOT" $VERSDOT
     printf "%-20s %s\n" "VERSUNDER" $VERSUNDER
     printf "%-20s %s\n" "GOROCO" $GOROCO
     printf "%-20s %s\n" "SIGNATURE" $SIGNATURE
     
     printf "\n"
     printf "%-20s %s\n" "SCRIPT_MENU_FILENAME" $SCRIPT_MENU_FILENAME
     printf "%-20s %s\n" "SCRIPT_ENV_FILENAME" $SCRIPT_ENV_FILENAME
     printf "%-20s %s\n" "KIT_LIV" $KIT_LIV
     printf "%-20s %s\n" "KIT_STAGE" $KIT_STAGE
     printf "%-20s %s\n" "KIT_REPOS" $KIT_REPOS
     printf "%-20s %s\n" "ZIP" $ZIP
     printf "%-20s %s\n" "ZIP_NBFILES_MIN" "$ZIP_NBFILES_MIN"
     printf "%-20s %s\n" "ZIP_NBFILES_MAX" "$ZIP_NBFILES_MAX"

     printf "\n"
     printf "%-20s %s\n" "ORACLE_BASE" $ORACLE_BASE
     printf "%-20s %s\n" "ORACLE_HOME" $ORACLE_HOME
     printf "%-20s %s\n" "LVNAME_OH" "$LVNAME_OH"
     printf "%-20s %s\n" "LVNAME_ICLI" "$LVNAME_ICLI"
     printf "%-20s %s\n" "LVNAME_CLI" "$LVNAME_CLI"

     printf "\n"
     printf "%-20s %s\n" "RPMs RH7 count" $( echo $RPM_RH7 | wc -w )
     printf "%-20s %s\n" "RPMs RH8 count" $( echo $RPM_RH8 | wc -w )
     printf "%-20s %s\n" "RPMs RH9 count" $( echo $RPM_RH9 | wc -w )

     printf "\n"
     printf "%-20s %-20s %-20s %-20s %-20s\n" "TOOLS" "TOOL NAME" "OWNER" "PERMISSIONS" "DEST. DIRECTORY"
     for i in ${!TOOL_NAME[@]}; do printf "%-20s %-20s %-20s %-20s %-20s\n" "" "${TOOLS_DIR_NAME}/${TOOL_NAME[$i]}" "${TOOL_OWNER[$i]}" "${TOOL_PERMS[$i]}" "${TOOL_DEST[$i]}"; done

     printf "\n"


} # show_vars

#------------------------------------------------------------------------------

# Donne la version de RedHat en fonction de la version majeurs
get_version()
{

     OS_MAJNUM=$(cat /etc/os-release  | grep VERSION_ID)
     OS_MAJNUM=${OS_MAJNUM/VERSION_ID=\"/}
     OS_MAJNUM=${OS_MAJNUM/\"/}
     OS_MAJNUM=$(echo $OS_MAJNUM | cut -d. -f1)
     # echo "OS_MAJNUM=$OS_MAJNUM"

     if [[ $OS_MAJNUM -le 7 ]] ; then
          VRH_=`cut  -d" " -f7 /etc/redhat-release`                         # OLD: Jusqu'en RH7, c'etait le 7eme champ.
     else
          VRH_=`sed -e 's/Server //' /etc/redhat-release | cut  -d" " -f6`  # NEW: En RH8, c'est devenu le 6eme champ
     fi
     echo $VRH_

}  # get_version


#------------------------------------------------------------------------------

kit_confirm()
{

     [[ $FORCE_YES = yes ]] && return $RET_OK
     
     if [ "$CONFIRM_STEP" = yes ]; then 
          echo -e "\n   Confirm (yes/no) : yes (automatic)"
          return $RET_OK
     else 
          echo -e "\n   Confirm (yes/no) : \c"
          read CONFIRM_STEP
          if [ "$CONFIRM_STEP" = yes ]; then 
               echo "        Step $STEP Confirmed." ; return $RET_OK
          else 
               echo "        Step $STEP Aborted."   ; return $RET_STEP_ABORTED
          fi
     fi

}  # kit_confirm

#------------------------------------------------------------------------------

cpBAK() { D=$(date +%Y-%m-%d_%H-%M-%S); F="$1.BAK.$D"; cp "$1" "$F"; echo "File copied to '$F'"; }

#------------------------------------------------------------------------------

mvBAK() { D=$(date +%Y-%m-%d_%H-%M-%S); F="$1.BAK.$D"; mv "$1" "$F"; echo "File renamed to '$F'"; }


#------------------------------------------------------------------------------

kit0_copy()
{

     echo "
#=======================================================================
# STEP_0 : Copy some files to your machine
#======================================================================="

     kit_confirm || return $RET_STEP_ABORTED

     #------------------------------------------------------------------
     # Deux repertoires de lancement sont admins, sinon forcage :
     #    Si on n'est ni dans KIT_LIV, ni dans KIT_STAGE :
     #------------------------------------------------------------------

     if [[ $force_yes = no ]]; then
     if [ `pwd` != $KIT_LIV  -a `pwd` != $KIT_STAGE ]; then
          echo -e "\tYou should be in '$KIT_LIV' or '$KIT_STAGE'"
          echo -e "\tForce install from here '`pwd`' (yes/no) ? \c"
          read FORCE_HERE
          [ "$FORCE_HERE" = yes ] || exit
     fi
     fi

     #-----------------------------------------------------------------
     # Conservation des install precedentes :
     #    Si un KIT_STAGE existe et qu'on n'est pas dedans :
     #-----------------------------------------------------------------

     if [ -d "$KIT_STAGE" -a `pwd` != $KIT_STAGE ]; then
          mv $KIT_STAGE $KIT_STAGE-$$
     fi

     mkdir -p     $KIT_STAGE
     [[ $? -ne 0 ]] && echo -e "\n\nCannot create directory '$KIT_STAGE'. Exiting." && exit $RET_ERROR_MKDIR
     chmod o+rx   $KIT_STAGE  $KIT_STAGE/..  /images

     #-----------------------------------------------------------------
     #                 IDEMPOTENCE
     # Si on est deja dans KIT_STAGE, alors ca recopie sur soi-meme !
     # Donc les cp -n vont eviter les messages "... are the same file"
     # Cela permet des lancer le mode auto (incluant ce step0)
     # depuis un KIT_STAGE deja garni.
     # (de toute facon, le /dev/null masque tout)
     #-----------------------------------------------------------------

     echo -e "\n  Copying files to $KIT_STAGE ..."

# echo "#!/bin/bash

# # Creation du script specifique pour le numero de version (ex: install_iclient1923.sh)
# ./install_iclient.sh -o current "\$\@"

# # fin
# " > $KIT_STAGE/install_iclient${VERSNUM}.sh 

     # cp       ./${VERSNUM_LONG}.env $KIT_STAGE/env_current.sh     2>/dev/null

     cp -n      $SCRIPT_MENU_FILENAME        $KIT_STAGE     2>/dev/null
     cp -n      $SCRIPT_ENV_FILENAME         $KIT_STAGE     2>/dev/null
     # cp -n      env_*sh                      $KIT_STAGE     2>/dev/null
     cp -n      *uninstall*sh                 $KIT_STAGE     2>/dev/null
     
     # Copy the list of tools
     mkdir -p ${KIT_STAGE}/${TOOLS_DIR_NAME}
     for i in ${!TOOL_NAME[@]}; do
          [[ ${TOOL_DEST[$i]} != "" ]] && cp -pn "${TOOLS_DIR_NAME}/${TOOL_NAME[$i]}" "${KIT_STAGE}/${TOOLS_DIR_NAME}/" \
                                       || cp -pn "${TOOLS_DIR_NAME}/${TOOL_NAME[$i]}" "${KIT_STAGE}/"
     done

     # cp -n      tools/tunsysctl              $KIT_STAGE     2>/dev/null
     # cp -n      tools/edf                    $KIT_STAGE     2>/dev/null    # Present si client.
     # cp -n      tools/oraenv                 $KIT_STAGE     2>/dev/null    # Present si client.

     if [[ $debug_level > 0 ]]; then
          echo
          echo "    VRH=$VRH    VKER=$VKER    VGLIBC=$VGLIBC"
          echo "    BTLIST=$BTLIST"
     fi

     cp -n -rp  STEP_RH$RH.REF     $KIT_STAGE     2>/dev/null

     chmod 755 $KIT_STAGE/*

     echo -e "\n  List of files in $KIT_STAGE :\n"
     ls -l $KIT_STAGE | grep -v "^total "
     echo "
          -----------------------------------------------------------
          Go to     $KIT_STAGE   then continue.
          -----------------------------------------------------------
          "

} # kit0_copy

#------------------------------------------------------------------------------

kit1_rpm()
{


echo "
#=======================================================================
# STEP_1 : Check and Add RPMs for Oracle ...
#=======================================================================
"

#=================
# FILTRE
#=================

     # case "$RH" in
     # 64|71|73|74|76|78|79|8?  ) echo ""           ;;  # Ces cas sont admis, on continue.
     # *              ) echo "Filtre RH" ; return 1 ;;  # Ces cas sont imprevus, on quitte la fonction.
     # esac

#=================
# RPM_CHECK
#=================

     echo -e "\n  RH$RH Install/Re-install the RPMs needed (yes/no) ? \c"
     kit_confirm || return $RET_STEP_ABORTED

#=================
# APT G3 ou G4
#=================

     # command -v subscription-manager   2>&1  1>/dev/null                         && APTc=G4 || APTc=G3
     # [ $(subscription-manager identity 2>/dev/null | grep -Ec APTPLATON) -ge 1 ] && APTi=G4 || APTi=G3

     # case "$APTc:$APTi" in
     # G4:G4 ) APT=G4 ; REPO_PREMIUM="APTPLATON_G*" ;;        # The Premium will not be used in G4.
     # *     ) APT=G3 ; REPO_PREMIUM="G*"      ;;
     # esac


     # case "$RH:$APT" in
     # ??:G3) REPO_STANDARD="standard"              ;;
     # 7?:G4) REPO_STANDARD="rhel-7-server-rpms"    ;;
     # 8?:G4) REPO_STANDARD="rhel-8-for-x86_64-baseos-rpms,rhel-8-for-x86_64-appstream-rpms" ;;
     # esac

     # RH=810
     case "$RH" in
          6*) REPO_STANDARD="standard"              ;;
          71) REPO_STANDARD="standard"              ;;
          7*) REPO_STANDARD="rhel-7-server-rpms"    ;;
          8*) REPO_STANDARD="rhel-8-for-x86_64-baseos-rpms,rhel-8-for-x86_64-appstream-rpms" ;;
          9*) REPO_STANDARD="rhel-9-for-x86_64-baseos-rpms,rhel-9-for-x86_64-appstream-rpms" ;;
     esac

     # APT           : $APT
     echo "
     ----------------------------------------------------
     REPO_STANDARD : \"$REPO_STANDARD\"
     ----------------------------------------------------"

     echo -e "\n  Installing RPMs ...
     "

     echo "Trying different networks:"

     # RESEAU FRANCE
     timeout 1 bash -c  'cat  </dev/null  >/dev/tcp/aptplaton.si.francetelecom.fr/80' 2>/dev/null && FQDN1=ok && echo "FQDN1 (RESEAU FRANCE)                is accessible" || echo "FQDN4 (RESEAU FRANCE)                is NOT accessible"
     timeout 1 bash -c  'cat  </dev/null  >/dev/tcp/aptplaton.itn.ftgroup/80'         2>/dev/null && FQDN2=ok && echo "FQDN2 (GIN - Group Internal Network) is accessible" || echo "FQDN4 (GIN - Group Internal Network) is NOT accessible"
     timeout 1 bash -c  'cat  </dev/null  >/dev/tcp/aptplaton-zoe.itn.ftgroup/443'    2>/dev/null && FQDN3=ok && echo "FQDN3 (Zone Outils d'Exploitation)   is accessible" || echo "FQDN4 (Zone Outils d'Exploitation)   is NOT accessible"
     timeout 1 bash -c  'cat  </dev/null  >/dev/tcp/aptplaton-rsc.itn.ftgroup/443'    2>/dev/null && FQDN4=ok && echo "FQDN4 (Reseau Sans Coutures)         is accessible" || echo "FQDN4 (Reseau Sans Coutures)         is NOT accessible"

     case "$FQDN1:$FQDN2:$FQDN3:$FQDN4" in
          *ok* ) echo "    At least one FQDN is accessible. OK."     ; FQDN_ACCESSIBLE=ok ;;
          *    ) echo "    No FQDN is accessible." ;;
     esac

     # Sur Canal Standard, il faut specifier l'archi.
     # Pour compat-db?? ; cela peut installer plusieurs compat_db, selon le contenu du repository.

# https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/supported-red-hat-enterprise-linux-7-distributions-for-x86-64.html#GUID-2E11B561-6587-4789-A583-2E33D705E498
# https://support.oracle.com/epmos/faces/DocumentDisplay?_afrLoop=215566621079783&id=2668780.1&_afrWindowMode=0&_adf.ctrl-state=cgqqzrobe_45

     KERNEL_HEADER="kernel-headers-`uname -r`"

     case "$VRH" in
          7* ) RPM_LIST=${RPM_RH7} ;;
          8* ) RPM_LIST=${RPM_RH8} ;;
          9* ) RPM_LIST=${RPM_RH9} ;;
          *  ) exit $RET_NO_RPM_FOR_OS ;;
     esac

     if [[ -z ${RPM_LIST} ]]; then
          printf "\n\n\tThe list of RPMs to install for this OS ($VRH) is empty.\n\tCheck the ${SCRIPT_ENV_FILENAME} and *.env files.\n\n"
          exit $RET_NO_RPMS
     fi

     if [ "$FQDN_ACCESSIBLE" = ok ]; then

          echo "
          #----------------------------------------------
          # Installation des RPMs par le Canal Standard :
          #----------------------------------------------"

          yum -y install --disablerepo="*" --enablerepo="$REPO_STANDARD"  $RPM_LIST

          [ "$?" = 0 ] && YUM_CANAL_STANDARD=ok
     fi

     return

#     if [ "$YUM_CANAL_PREMIUM" != ok -a "$YUM_CANAL_STANDARD" != ok ]; then
#
#          echo "
#          #-----------------------------------
#          # Inslallation des RPMs par le kit :
#          #-----------------------------------"
#
#          [ -d "$RPM_DIR_SUBSTITUTE" ] && RPM_DIR=$RPM_DIR_SUBSTITUTE
#
#          if [ `ls -1 $KIT_STAGE/$RPM_DIR | grep -c ".rpm"` = 0 ]
#          then
#               echo "    Pas de rpm sous [$KIT_STAGE/$RPM_DIR] ou repertoire absent".
#          else
#                ls -1 $KIT_STAGE/$RPM_DIR/*.rpm | xargs yum install -y --disablerepo="*"
#               [ "$?" = 0 ] && YUM_CANAL_KIT=ok
#          fi
#     fi

} # kit1_rpm

#------------------------------------------------------------------------------

doc_for_me()
{
:
     #----------------------- Doc pour moi -------------------------
     # RECUPERATION des RPMS pour constituer un .tar :
     # Pour loader sous /var/cache/apt/archives :
     #               apt-get install Pkg -d -f
     # Si deja installes, faire d'abort  : apt-get remove  Pkg
     #                   puis apt-get install Pkg -d -f
     #                   puis apt-get install Pkg
     # Enfin : tar cvf .... des .rpm qu'on veut fournir.
     #--------------------------------------------------------------

     #----------------------------------------
     # Extraction et installation de ces RPM :
     #----------------------------------------

#        case `rpm -qa | grep "^glibc-[0-9]" | cut -c15,16` in
#        19 ) TAR_NAME=rpmRH40_ora102_G7R0C1.tar ;;
#        25 ) TAR_NAME=rpmRH40_ora102_G7R0C2.tar ;;
#        *  ) echo "WARNING : Version de glibc imprevue."
#        esac
#
#     mkdir -p $KIT_STAGE/RPM_RH40
#        tar -xvf $TAR_NAME -C $KIT_STAGE/RPM_RH40
#        rpm -Uvh --replacepkgs $KIT_STAGE/RPM_RH40/*.rpm 2>&1 | grep -v "signature: NOKEY"

} # doc_for_me

#------------------------------------------------------------------------------

kit2_volumes()
{
[ "$1" = install ] && echo "
#=======================================================================
# STEP_2 : Create User, Group, FS, LV ...
#=======================================================================
"
#----------------------------------------------------------------------------
#               Creating Spaces before Oracle Installation
# Old script :
#     LvSizeLNX=480  LvSizeAIX=480   LvSizeHP=480  LvSizeSUN=480
#     LvSizeLNX=5000 LvSizeAIX=6000  LvSizeHP=5000 LvSizeSUN=5000
#     Quelques arrondis : 480=15*32  1024=32*32  2400=75*32  2944=92*32  4480=140*32

     LvName1=oracle_lv

     # LvName2=oracle_${VERSNUM}_lv

     # case "$RDBMS_FIELD" in
          # ""|none             ) LvName2=oracle_${VERSMAJ}_lv     ;;
          # na             ) LvName2=oracle_na_${VERSMAJ}_lv  ;;
          # # [A-Z]*|[a-z]*|[0-9]* ) LvName2=oracle_${RDBMS_FIELD}_${VERSMAJ}_lv ;;
          # [A-Z]*|[a-z]*|[0-9]* ) LvName2=oracle_${RDBMS_FIELD}_${VERSNUM}_lv ;;
     # esac

     LvName2=oracle_na_icli${VERSNUM}_lv                                   # SPECIFIC CLIENT

 # Since 11.2.0.3.2 (PSU apr2012) : LvSize1 become 1024   (instead of 480)
 # Since 12.1.0.2.X (PSU apr2016) : LvSize2 become 10000  (instead of 9000)
 # Since 18c        (july 2018)   : LvSize2 become 14000
 # Marge pour les patchs (2020)   : LvSize2 become 16000
 # Since 19.10      (jan  2021)   : LvSize2 become 18000

     LvSize1=1024
     LvSize2=700

# En projet : Prevoir les tailles pour client seul puis tar de l'InstantClient.
#----------------------------------------------------------------------------

VOLACTION=$1   # [ install | uninstall_version | uninstall_account ]

#----------------------------------------------------------------------------
case "$OS-$VOLACTION" in
Linux-install )
# If you want to use vg_infra or infravg instead if rootvg,
# Here is the 'vi' order from this line : Esc:.,+42s/rootvg/vg_infra/g

#vgdisplay HelloWorld 2>&1 1>/dev/null # just to avoid the message : /dev/hdx: open failed: no media found

  #groupadd -g 3099 oinstall
  #groupadd -g 3000 $GRP
  #useradd -u 3000 -g oinstall     -G $GRP -d $ORACLE_BASE -m -s /usr/bin/ksh $USR
  #usermod         -g oinstall  -a -G $GRP   $USR
     
     local oracle_user_shell="/usr/bin/bash"
     #si l'on veut utiliser ksh
     if [[ $USE_KSH = yes ]]; then
          oracle_user_shell="/usr/bin/ksh"
          printf "\nRequest to use ksh. "
     
          # Le user existe?
          getent passwd $USR >/dev/null
          # Si le user n'existe pas et qu'on devra le creer
          if [[ $? -ne 0 ]]; then
               printf "The \"$USR\" user will have to be created. "
               yum list installed | grep ksh >/dev/null
               # Si ksh n'est pas installe (etat normal pour Platon RH8+)
               if [[ $? -ne 0 ]]; then
                    printf "ksh needs to be installed. "
                    yum -y install ksh
               else
                    printf "ksh is already installed.\n"
               fi
          else
               printf "\"$USR\" user already exists.\n"
          fi # user exists
     
          printf "\n"
     fi
# exit 0

ORDER_LIST="
groupadd  -g 3000 $GRP
mkdir     -p $ORACLE_BASE
useradd   -u 3000 -g $GRP -d $ORACLE_BASE -m -s ${oracle_user_shell} $USR
chage     -M 99999 $USR
chown     $USR:$GRP $ORACLE_BASE
chmod     755 $ORACLE_BASE
lvcreate  -L $LvSize1 -n $LvName1 $WIPE infravg
mkfs.$FSTYP /dev/infravg/$LvName1
mount     /dev/infravg/$LvName1 $ORACLE_BASE
mkdir     -p $ORACLE_HOME
chown     $USR:$GRP $ORACLE_HOME $ORACLE_HOME/..
chmod     755 $ORACLE_HOME $ORACLE_HOME/..
lvcreate  -L $LvSize2 -n $LvName2 $WIPE infravg
mkfs.$FSTYP /dev/infravg/$LvName2
mount     /dev/infravg/$LvName2 $ORACLE_HOME
touch     /etc/signatures/$SIGNATURE"

     [ `grep -c "^/dev/infravg/$LvName1" /etc/fstab` = 0 ] && ORDER_LIST="$ORDER_LIST
echo \"/dev/infravg/$LvName1       $ORACLE_BASE       $FSTYP defaults,nodev 1 2\" >>/etc/fstab"

     [ `grep -c "^/dev/infravg/$LvName2" /etc/fstab` = 0 ] && ORDER_LIST="$ORDER_LIST
echo \"/dev/infravg/$LvName2 $ORACLE_HOME  $FSTYP defaults,nodev 1 2\" >>/etc/fstab"

  # Pour prise en compte du nodev (sinon, cela sera pris en compte au prochain reboot) :
  ORDER_LIST="$ORDER_LIST
     mount -o remount $ORACLE_BASE
     mount -o remount $ORACLE_HOME"

if [ "$SPAD" = yes ]; then
ORDER_LIST="$ORDER_LIST
     mkdir -p         /opt/oracle/avdfagent
     chown $USR:$GRP  /opt/oracle/avdfagent
     chmod 755        /opt/oracle/avdfagent
     lvcreate  -L 850       -n avdfagent_lv  $WIPE infravg
     mkfs.$FSTYP  /dev/infravg/avdfagent_lv
     mount        /dev/infravg/avdfagent_lv  /opt/oracle/avdfagent"

    [ `grep -c "^/dev/infravg/avdfagent_lv " /etc/fstab` = 0 ] && ORDER_LIST="$ORDER_LIST
echo \"/dev/infravg/avdfagent_lv  /opt/oracle/avdfagent  $FSTYP defaults,nodev 1 2\" >>/etc/fstab"

  ORDER_LIST="$ORDER_LIST
     mount -o remount /opt/oracle/avdfagent"
fi


;;


#-------------------------------------------------------------------
# Agrandissement online sans faire umount (FS de type ext3 ou ext4) :
# Pour verifier si l'option resize_inode est active (en general c'est actif) :
# tune2fs -l /dev/infravg/oracle_na_180300_lv | grep resize_inode
#
# lvresize  -L 14000M   /dev/infravg/oracle_na_180300_lv
# resize2fs   /dev/infravg/oracle_na_180300_lv
#-------------------------------------------------------------------

Linux-uninstall_version )
     ORDER_LIST="
          umount   $ORACLE_HOME
          lvremove -f /dev/infravg/$LvName2
          cp /etc/fstab /etc/fstab.$$
          egrep -v \"^/dev/infravg/$LvName2( |    )\" /etc/fstab.$$ > /etc/fstab
          rmdir $ORACLE_HOME
          rm /etc/signatures/$SIGNATURE
          "
;;

Linux-uninstall_account )
     if [ "$SPAD" = yes ]
     then
     ORDER_LIST="
          umount   /opt/oracle/avdfagent
          lvremove -f /dev/infravg/avdfagent_lv
          cp /etc/fstab /etc/fstab.$$-SPAD
          egrep -v \"^/dev/infravg/avdfagent_lv( |     )\" /etc/fstab.$$-SPAD > /etc/fstab
          "
     fi

     ORDER_LIST="$ORDER_LIST
          umount   $ORACLE_BASE
          lvremove -f /dev/infravg/$LvName1
          userdel -r $USR
          groupdel $GRP
          cp /etc/fstab /etc/fstab.$$
          egrep -v \"^/dev/infravg/$LvName1( |    )\"  /etc/fstab.$$ > /etc/fstab
          "

;;

esac


          #================================================
          # Execution of ORDER_LIST ( common for all OS )
          #================================================

if [ "$CONFIRM_AUTO" = yes ]; then
echo "
        -----------------------------------------------------
        | Here is the list of the orders
        | to be launched automatically :
        -----------------------------------------------------"
else  [ "$VOLACTION" = install ] && MSG_AUTO="
     |     or 'auto' to proceed all orders." ||

echo "
     -----------------------------------------------------
     | You can confirm the following orders, one by one :
     | To do this : answer 'yes' for each order. $MSG_AUTO
     -----------------------------------------------------"
fi

echo "$ORDER_LIST"
     # Gestion des erreurs
     >/tmp/errors

echo "$ORDER_LIST" | while read LINE
do
    [ -z "$LINE" ] && continue
    echo "
    -------------------------------------------------
    $LINE"

     [ "$VOLACTION" = install ] && OPT_AUTO=/auto || OPT_AUTO=""

     if [ "$CONFIRM_AUTO" = yes ]; then
          : # Launch this order and all the following orders.
     else
          echo -e "    Confirm (yes/abort$OPT_AUTO) ? \c"
          read REPLY </dev/tty
          case "$REPLY" in
               yes  ) ;;   # Launch only this order.
               auto ) if [ "$VOLACTION" = install ]; then
                         echo "   #  Launching all next orders ..."  ; CONFIRM_AUTO=yes
                      else
                         echo "   #  Auto only allowed for install." ; break
                      fi ;;
               *    ) echo " Abort this order and all next orders." ; break ;;
          esac
     fi # CONFIRM_AUTO

     sleep 1
     eval $LINE 2>&1 | tee -a /tmp/errors

done

ERRORS=$(cat /tmp/errors | grep -E "Could not|does not exist|bad option|insufficient" )
if [ "a$ERRORS" != "a" ]; then
     printf "\n\n--------------------------------------------------------------------\n"
     printf "Errors: (please check if relevant)\n"
     printf "=======\n"
     printf "\n%s\n\n" "$ERRORS"
     printf "\n--------------------------------------------------------------------\n"
fi


# chown-chmod have been already made before the mount.
# then, we replay these chown-chmod here, at the end of this step :
if [ "$VOLACTION" = install ]; then
  ( chown $USR:$GRP     $ORACLE_BASE $ORACLE_HOME  $ORACLE_HOME/..  $ORACLE_BASE/avdfagent
    chmod 755           $ORACLE_BASE $ORACLE_HOME  $ORACLE_HOME/..  $ORACLE_BASE/avdfagent
    chown -R root:root  $KIT_STAGE ) 2>/dev/null

     RES=$( lvs | grep $LvName1 )
     [[ -z $RES ]] && printf "\n\nLe LV \"$LvName1\" (HOME du user oracle) n'existe pas!\n\n" && return $RET_NO_ORAHOME
     RES=$( lvs | grep $LvName2 )
     [[ -z $RES ]] && printf "\n\nLe LV \"$LvName2\" (ORACLE_HOME) n'existe pas!\n\n" && return $RET_NO_ORACLE_HOME

fi


return  $RET_OK

}

#=============================================================================

kit3_kernel_params()
{

     case "$OS" in
     Linux )
     case "$PATH" in
     */usr/local/bin* ) PATH=$PATH:/usr/ccs/bin:/etc:/usr/openwin/bin:$ORACLE_HOME ;;
     * ) PATH=$PATH:/usr/ccs/bin:/etc:/usr/openwin/bin:/usr/local/bin:$ORACLE_HOME ;;
     esac
     LD_LIBRARY_PATH=$ORACLE_HOME:/usr/lib
     OS_SPECIFIC=""
     ALIAS_PSORA='ps -efww | egrep "[p]mon|[t]ns"'

     #--------------------------------------------------------------------------
     sleep 1 ; echo -e "\n=== Param SYSTEM /etc/sysctl.d/98-oracle.conf ..."

     # Comme en 10g, 11g et 12c, on abondait le fichier /etc/sysctl.conf,
     # on laisse /etc/sysctl.conf tel quel et on genere le nouveau /etc/sysctl.d/98-oracle.conf
     #
     # Ce sera parfois redondant : la suppression dans /etc/sysctl.conf pourra etre faire manuellement.
     # Comme on n'ajoute que des valeurs plus grandes. Pour les lignes presentes dans sysctl.conf
     # et absente de 98-oracle.conf : Il faudra les reporter dans 98-oracle.conf


if [ -f /etc/sysctl.d/98-oracle.conf ]
then echo "
     INFO : Le fichier /etc/sysctl.d/98-oracle.conf est deja present."
fi


echo "#---------- Begin Tuning for Oracle `date` ----------#" >> /etc/sysctl.d/98-oracle.conf

./tunsysctl         kernel.sem          = 4096 4194304 100 1024
./tunsysctl -nohead kernel.shmall       = 16777216
./tunsysctl -nohead kernel.shmmax       = 68719476736            # This Value is reused below for a test.
./tunsysctl -nohead kernel.shmmni       = 4096

./tunsysctl -nohead kernel.msgmni       = 512
./tunsysctl -nohead kernel.msgmax       = 131072
./tunsysctl -nohead kernel.msgmnb       = 131072

./tunsysctl -nohead fs.file-max         = 6815744
./tunsysctl -nohead fs.aio-max-nr       = 1048576

./tunsysctl -nohead net.core.rmem_default = 2097152
./tunsysctl -nohead net.core.rmem_max     = 16777206
./tunsysctl -nohead net.core.wmem_default = 2097152
./tunsysctl -nohead net.core.wmem_max     = 16777206

./tunsysctl -nohead vm.nr_hugepages               = 10                # RH6=0   RH7=10
./tunsysctl -nohead vm.swappiness                 = 10                # RH6=20  RH7=10
./tunsysctl -nohead vm.dirty_background_ratio     = 3                 # RH6=10  RH7=3
./tunsysctl -nohead vm.dirty_ratio                = 80                # RH6=20  RH7=10
./tunsysctl -nohead vm.dirty_expire_centisecs     = 3000              #    RHx:3000
./tunsysctl -nohead vm.dirty_writeback_centisecs  = 500               #    RHx:500

echo "#---------- End Tuning for Oracle `date` ------------#" >> /etc/sysctl.d/98-oracle.conf

#------------------------------------------------------
# Params elimines ou dieses avec la justification :
#------------------------------------------------------
# tunsysctl net.ipv4.ip_local_port_range     = 9000 65500
# REMARK    net.ipv4.ip_local_port_range : initial values 49152 65535 from Platon are mandatory
#           to avoid conflicts : http://support-platon.si.francetelecom.fr/view.php?id=418
# tunsysctl sunrpc.tcp_slot_table_entries = 128                  # RHx:128
#------------------------------------------------------
# Vu avec Arnaud BONNET le 3 fev 2016 :
# Les randomize_va_space=0 et exec-shield=0  avaient ete ajoutes 04nov2011 pour le bug 8527473
# qui fut revele en RH5 :
#      ORA-00445: Background Process "xxxx" Did Not Start After 120 Seconds (Doc ID 1345364.1)
# mais ceci pose un probleme de securite : donc on le diese desormais sur le kit 12c
# dans la mesure ou le kit 12c n'est prevu que pour RH6 et RH7 :
# echo "
# kernel.randomize_va_space     = 0
# kernel.exec-shield            = 0" >> /etc/sysctl.conf
#------------------------------------------------------

     sleep 1 ; echo -e "\n=== Update dynamic values using /etc/sysctl.d/98-oracle.conf ..."

     sysctl -p /etc/sysctl.d/98-oracle.conf

     sleep 1 ; echo -e "\n=== List and check sysctl -p ..."

#     echo "\n  => If no eth1, then some normal errors are displayed \n"
     sysctl -p  2>&1 1>sysctl-p.trc
     echo

     #--------------------------------------------------------------------------
     sleep 1 ; echo -e "\n=== Param transparent_hugepage in /etc/rc.local ..."
     if [ "$THP" = enabled_from_platon ]; then
          if egrep -q "redhat_transparent_hugepage" /etc/rc.local; then
               echo "         Param redhat_transparent_hugepage already exist in /etc/rc.local"
          else

cat >>/etc/rc.local<<ENDTHP
echo never >/sys/kernel/mm/transparent_hugepage/enabled
echo never >/sys/kernel/mm/transparent_hugepage/defrag
ENDTHP
          echo never >/sys/kernel/mm/transparent_hugepage/enabled
          echo never >/sys/kernel/mm/transparent_hugepage/defrag

         fi
     fi
          #========================================================================
          #  Pour le parametre 'elevator' voici les valeurs issues de Platon :
          #
          #                   RH6  RH7
          #         --------------- ------- ----------
          #         VirtualMachine  'noop'   'noop'
          #         PhysicalMachine 'cfq'   'deadline'
          #         --------------- ------- ----------
          #
          #  De plus, si on est sur une VM, alors il ne faut pas changer la valeur.
          #  Donc au final, on ne touche a rien.
          #========================================================================

     #--------------------------------------------------------------------------
     sleep 1 ; echo -e "\n=== Add sysctl -p -q to  /etc/rc.local ..."

     if egrep -q "/sbin/sysctl" /etc/rc.local; then
          echo "         /sbin/sysctl -q -p is already present in /etc/rc.local"
     else
          echo "/sbin/sysctl -q -p" >> /etc/rc.local
     fi


     #--------------------------------------------------------------------------
     sleep 1 ; echo -e "\n=== Param SYSTEM in /etc/security/limits.conf ..."

     if grep -q "oracle soft nproc" /etc/security/limits.conf; then
          echo "         Values already exist in /etc/security/limits.conf"
     else
cp /etc/security/limits.conf /etc/security/limits.conf.BeforeOracle
sed -i '/^oracle /d' /etc/security/limits.conf
cat >> /etc/security/limits.conf  <<ENDCFG
oracle soft nproc          16384
oracle hard nproc          16384
oracle soft nofile         65536
oracle hard nofile         65536
oracle soft memlock    unlimited
oracle hard memlock    unlimited
oracle soft stack          10240
oracle hard stack          32768
ENDCFG
     fi
          #========================================================================
          # Requis pour Peoplesoft et RAC :
          #    time(seconds)        unlimited
          #    file(blocks)         unlimited
          #    data(kbytes)         unlimited
          #    stack(kbytes)        unlimited
          #    memory(kbytes)       unlimited
          #    coredump(blocks)     8192
          #    nofiles(descriptors) unlimited
          #========================================================================


     #--------------------------------------------------------------------------
     sleep 1 ; echo -e "\n=== Param SYSTEM /etc/profile ..."
     if grep -q "USER = oracle" /etc/profile; then
          echo "         These 'ulimit' already exist in /etc/profile"
     else
          echo "
          if [ \$USER = oracle ]
          then if [ \$SHELL = /bin/ksh -o \$SHELL = /usr/bin/ksh ]
               then ulimit -p 16384
                 ulimit -n 65536
               else ulimit -u 16384 -n 65536
               fi
          fi " >>/etc/profile
     fi

     #--------------------------------------------------------------------------
     # Cette partie est inutile car cette ligne existe deja dans /etc/pam.d/system-auth
     # qui est lu en amont de /etc/pam.d/login :
     #
     # sleep 1 ; echo "\n=== Param SYSTEM /etc/pam.d/login ..."
     #
     # if grep -q "session    required  pam_limits.so"   /etc/pam.d/login
     # then  echo "      This Param already exists in /etc/pam.d/login"
     # else  echo "session    required  pam_limits.so" >>/etc/pam.d/login
     # fi
     #--------------------------------------------------------------------------

     case "$VRH" in
     7.* )
          #--------------------------------------------------------------------------
          sleep 1 ; echo -e "\n=== Param SYSTEM /etc/tmpfiles.d/oracle.conf ..."

          if grep -q "x /tmp/.oracle" /etc/tmpfiles.d/oracle.conf
          then
               echo -e "         /tmp/.oracle is already excluded from /etc/tmpfiles.d/oracle.conf"
          else
               echo -e "x /tmp/.oracle"      >> /etc/tmpfiles.d/oracle.conf
               echo -e "x /var/tmp/.oracle" >> /etc/tmpfiles.d/oracle.conf
               systemctl  restart  systemd-tmpfiles-clean.timer
          fi

          #--------------------------------------------------------------------------
          sleep 1 ; echo -e "\n=== Param SYSTEM spoof dans /etc/host.conf ..."

          sed -i -e 's:^spoof:#spoof:' -e 's:^nospoof:#nospoof:'  /etc/host.conf

          #--------------------------------------------------------------------------
          sleep 1 ; echo -e "\n=== Param SYSTEM alternatives pour /bin/mksh ..."

          alternatives --set ksh /bin/mksh   # Force /bin/mksh (instead of /bin/ksh93)

          alternatives --list
               # Example of --list
               #    libnssckbi.so.x86_64    auto    /usr/lib64/pkcs11/p11-kit-trust.so
               #    ksh            manual  /bin/mksh
               #    ld             auto    /usr/bin/ld.bfd
               #    mta                 auto    /usr/sbin/sendmail.sendmail
               #    emacs.etags         auto    /usr/bin/etags.emacs
               #    libnssckbi.so       auto    /usr/lib/nss/libnssckbi.so
               #    pax            auto    /usr/bin/opax

          ;;
     esac

     ;;

#    AIX   )
#
#     PATH=$PATH:/usr/local/bin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch
#     OS_SPECIFIC="
#  unset LD_LIBRARY_PATH                 # empty on AIX
#  export LIBPATH=$ORACLE_HOME/lib
#  export SKIP_ROOTPRE=TRUE              # only for AIX
#  export AIXTHREAD_SCOPE=S              # only for AIX
#     "
#     ALIAS_PSORA='ps -ef | egrep "[p]mon|[t]ns"'
#
#     sleep 1 ; echo -e "\n=== rootpre.sh and inittab ..."
#     cd $KIT_STAGE/rootpre
#     ./rootpre.sh
#     sed -e 's/orapw:2:/orapw:23:/' /etc/inittab > /etc/inittab.oraold
#        mv  -f /etc/inittab.oraold  /etc/inittab
#
#
#
#     sleep 1 ; echo -e "\n=== Ulimit and chuser ..."
#
#     # ULIMIT :
#     # 4194303 etait le plafond de 2Go pour fsize
#     #  2Go moins 1 bloc de 512 : ((2*1024*1024*1024)/512)-1)
#     #  (si on ajoute 1 ; cela etait refuse par AIX)
#
#     # Ici : les prerequis qui iront dans /etc/security/limits :
#     # Requis 11.2.0.3               # Requis_10g  ulimit -a                Default
#     #-------------------------------------------------------------------------------
#     chuser cpu=-1        oracle     # -1          unlimited time(seconds)  unlimited
#     chuser fsize=-1      oracle     # -1          unlimited file(blocks)   4194303
#     chuser data=-1       oracle     # 2097152     1048576 data(kbytes)     131072
#     chuser stack=-1      oracle     # 65536       32768   stack(kbytes)    32768
#     chuser rss=-1        oracle     # 4091360     2045680 memory(kbytes)   32768
#     chuser core=2097151  oracle     # 2097151     coredump(blocks)         2097151
#     chuser nofiles=4096  oracle     # 4096        nofiles(descriptors)     2000
#
#     # New in 11.2.0.2 :
#     chdev -l sys0 -a maxuproc=16384 #  Check :  lsattr -El sys0
#     chuser nproc=16384      oracle  #  Check :  cat /etc/security/limits
#     chuser nproc_hard=16384 oracle  #  Check :  cat /etc/security/limits
#
#     # Added Nov2011 for 11.2.0.3 :
#     chuser stack_hard=-1    oracle  #  Check :  cat /etc/security/limits
#     chdev -l sys0 -a ncargs=256     #  Required 128 but minimum 256 on AIX 6.1
#     ioo -o aio_maxreqs=65536
#
#     ;;

#    HP-UX )
#     PATH=$PATH:/usr/local/bin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch
#     LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
#     OS_SPECIFIC="
#  export SHLIB_PATH=$ORACLE_HOME/lib32:/lib:/usr/lib
#     "
#     ALIAS_PSORA='ps -ef | egrep "[p]mon|[t]ns"'
#
#     # LIENS REQUIS SELON DOC ORACLE (normalement deja presents) :
#     #------------------------------------------------------------
#     cd /usr/lib
#     ln -s /usr/lib/libX11.3 libX11.sl      2>/dev/null
#     ln -s /usr/lib/libXIE.2 libXIE.sl      2>/dev/null
#     ln -s /usr/lib/libXext.3 libXext.sl    2>/dev/null
#     ln -s /usr/lib/libXhp11.3 libXhp11.sl  2>/dev/null
#     ln -s /usr/lib/libXi.3 libXi.sl        2>/dev/null
#     ln -s /usr/lib/libXm.4 libXm.sl        2>/dev/null
#     ln -s /usr/lib/libXp.2 libXp.sl        2>/dev/null
#     ln -s /usr/lib/libXt.3 libXt.sl        2>/dev/null
#     ln -s /usr/lib/libXtst.2 libXtst.sl    2>/dev/null
#     ;;

#    SunOS )
#     PATH=$PATH:/etc:/usr/ccs/bin:/usr/openwin/bin:/usr/local/bin:$ORACLE_HOME/bin::$ORACLE_HOME/OPatch
#     LD_LIBRARY_PATH=$ORACLE_HOME/lib32:/lib:/usr/lib
#     OS_SPECIFIC="
#     LD_LIBRARY_PATH_64=$ORACLE_HOME/lib:/lib:/usr/lib
#     "
#     ;;
    
    esac  # case OS

} # kit3_kernel_params

#=============================================================================

kit3_operate()
{
#----------------------

[ "$1" = uninstall   ] && return $RET_STEP_ABORTED  # the following lines will not be executed.

#----------------------

# STEP_3 : Install Tuning OS + .profile + oratab + oraInst.loc

[ "$1" = install ] && echo "
#=======================================================================
# STEP_3 : Install .profile + oratab + oraInst.loc
#======================================================================="

     kit_confirm || return $RET_STEP_ABORTED

     case "$PATH" in
          */usr/local/bin* ) PATH=$PATH:/usr/ccs/bin:/etc:/usr/openwin/bin:$ORACLE_HOME ;;
          * ) PATH=$PATH:/usr/ccs/bin:/etc:/usr/openwin/bin:/usr/local/bin:$ORACLE_HOME ;;
     esac
     LD_LIBRARY_PATH=$ORACLE_HOME:/usr/lib
     OS_SPECIFIC=""
     ALIAS_PSORA='ps -efww | egrep "[p]mon|[t]ns"'

     # kit3_kernel_params
     

#----------------------------------------------------------------------
# sleep 1 

echo -e "\n=== .profile for oracle account ..."

# Si un .profile existe, nous n'allons pas l'ecraser mais en creer un tagge
PROFILE=$ORACLE_BASE/.profile
if [[ -f ${PROFILE} ]]; then

     PROFILE=${PROFILE}".icli_"${VERSNUM}
fi

cp -p $ORACLE_BASE/.profile $ORACLE_BASE/.profile.$$ 2>/dev/null


cat <<-FINCAT1 > ${PROFILE}        # no-quote + >.
#----------------------------------------------------------------------
[ -r /etc/motd ] && cat /etc/motd
export ORACLE_SID=XXX
export ORACLE_BASE=$ORACLE_BASE
export ORACLE_HOME=$ORACLE_HOME
#export ORA_NLS33=$ORACLE_HOME/ocommon/nls/admin/data
#export ORA_NLS10=$ORACLE_HOME/nls/data          # Requis pour 12c, 18c, 19c
#export ORA_NLS11=$ORACLE_HOME/nls/data
export NLS_LANG=american_america.we8iso8859p15

export PATH=$PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH
unset JAVA_HOME
$OS_SPECIFIC

alias psora='$ALIAS_PSORA'
FINCAT1

cat <<-'FINCAT2' >> ${PROFILE}     # quote + >>.
alias sysdba='sqlplus     "/as sysdba"'
alias sysdbas='sqlplus -s "/as sysdba"'
#alias rman='$ORACLE_HOME/bin/rman'
#alias rlite='cd $ORACLE_BASE/dba/rman ; ./rman_lite'
alias oper='/opt/operating/bin/OperateOracleAll.ksh'
alias kmora='/opt/oracle/dba/suplex/kmora/kmora.sh'

alias lrt='ls -lrt'
alias hom='cd $ORACLE_HOME'
alias tns='cd $ORACLE_HOME/network/admin'

TMOUT=43200       # 12 hours
TIMEOUT=$TMOUT
umask 022
set -o vi
export HNAME=`uname -n`
export PS1='[ $HNAME : $LOGNAME : $ORACLE_SID ]> '

echo "
         _______________________________________________________
        |                                  |
        |            Set the ORACLE_SID :   . oraenv      |
        |_______________________________________________________|
        |_________________Other command or alias________________|
        |                                  |
        |    edf   psora  otab [-w]   sysdba   oper   rlite     |
        |    tns    dbs    pfile    bdump    udump    alert     |
        |_______________________________________________________|
     "
FINCAT2

chown $USR:$GRP ${PROFILE}

#----------------------------------------------------------------------
sleep 1 ; echo -e "\n=== Operating Scripts ..."

     local dest CMD
     # Copying the tools
     for i in ${!TOOL_NAME[@]}; do
          
          # Si une destination est definie, on le copie en backupant l'existant si besoin
          if [[ ${TOOL_DEST[$i]} != "" ]]; then

               dest=${TOOL_DEST[$i]}/${TOOL_NAME[$i]}
               printf "Copying %s to %s\n" "${TOOL_NAME[$i]}" ${TOOL_DEST[$i]}

               # Backup
               [[ -f ${dest} ]] && mvBAK "${dest}"

               # Copie
               printf -v CMD "cp -pn ${KIT_STAGE}/${TOOLS_DIR_NAME}/${TOOL_NAME[$i]} ${TOOL_DEST[$i]}/ "
               printf "\t${CMD}\n"
               $CMD

               # ownership
               if [[ ${TOOL_OWNER[$i]} != "" ]]; then 
                    printf -v CMD "chown ${TOOL_OWNER[$i]} ${dest}"
                    printf "\t${CMD}\n"
                    $CMD
               fi

               # permissions
               if [[ ${TOOL_PERMS[$i]} != "" ]]; then
                    printf -v CMD "chmod ${TOOL_PERMS[$i]} ${dest}"
                    printf "\t${CMD}\n"
                    $CMD
               fi

          fi

     done

     # # edf: backup et installation
     # if [[ -f /usr/local/bin/edf ]]; then
          # mvBAK "/usr/local/bin/edf"
     # fi
     # cp $KIT_STAGE/edf  /usr/local/bin/
     # chown $USR:root /usr/local/bin/edf
     # chmod 755 /usr/local/bin/edf

     # # oraenv: backup et installation
     # if [[ -f /usr/local/bin/oraenv ]]; then
          # mvBAK "/usr/local/bin/oraenv"
     # fi
     # cp $KIT_STAGE/oraenv  /usr/local/bin/
     # chown $USR:root /usr/local/bin/oraenv


}  # kit3_operate

#------------------------------------------------------------------------------

kit4_unzip()
{
echo -e "
#=======================================================================
# STEP_4 : Unzip the package ...
#=======================================================================
"

# Remarque : Commande identique pour Linux et AIX mais comportement distinct.
#         (df -k :  2 lignes sur Linux    mais   1 ligne sur AIX)

     case "$OS" in HP-UX) DF="bdf" ;; *) DF="df -Pk" ;; esac

     DISPO=`$DF | egrep " $ORACLE_HOME( |$)" | awk '{print $4}'`
     echo -e "   Free Space in $ORACLE_HOME :        $DISPO K"

     REQUIS=600

     if [ "$DISPO" -le "$REQUIS" ]; then
     echo -e "
     Insufficient Space in $ORACLE_HOME :
                        required : $REQUIS K
                        found    : $DISPO K
          Continue (yes/no) ? \c"
          read CONTINUE
          [ "$CONTINUE" = yes ] || return
     fi

     #--------------------------------------------------------------------
     # The tar was made with the following command :
     # Files cleared in ../bin before the tar : ls -l  *[^.][O,0]
     #
     # cd /opt/oracle/na/18.6.0
     # tar -cvjf /images/oracle/$ZIP .patch_storage *
     # Ca genere un fichier de 4,3GB , donc a peine moins que le fichier de l'editeur de 4,5GB :
     #  4388718863 Aug  6 17:41 Oracle_180300_RH_1of1.bz2
     # How To Avoid Disk Full Issues Because OPatch Backups Take Big Amount Of Disk Space. [ID 550522.1]
     # https://support.oracle.com/epmos/faces/DocumentDisplay?_afrLoop=287265004881555&id=550522.1&_adf.ctrl-state=1bz7gbfe6e_57#aref_section22
     #
     #
     # cd /opt/oracle/na/
     # tar -cvjf /liv/LINUX/ora_RH/$ZIP .patch_storage .opatchauto_storage *  #=> 3,2GB
     # cd /opt/oracle/na/19.6.0
     # tar -cvjf /liv/LINUX/ora190600_RH/$ZIP . #Mieux que "*"  => 3,7GB
        #--------------------------------------------------------------------
     # tar -cvjf /liv/LINUX/ora190600_RH/$ZIP  --exclude='./dbs/*POVO01*' --exclude='./network/admin/*ora'

     cd $KIT_STAGE
     [ -f $KIT_LIV/$ZIP ] && DIRZIP=$KIT_LIV
     [ -f $KIT_STAGE/$ZIP ] && DIRZIP=$KIT_STAGE

     if [ -z "$DIRZIP" ]; then
          echo -e "
     Directory of the ZIP file :
     ($KIT_LIV or else or q=Quit ) : \c"
          read DIRZIP  ;
          if [ "$DIRZIP" = q -o -z "$DIRZIP" ]; then
               echo -e "\tAbort. Unzip not launched."
               return
          fi
    fi

    echo -e "
    cd $ORACLE_HOME
    tar -xjvf $DIRZIP/$ZIP
    "
    kit_confirm || return $RET_STEP_ABORTED

     echo -e "
     -----------------------------------------------
     tar xjvf $DIRZIP/$ZIP  -C $ORACLE_HOME
     -----------------------------------------------"  | tee -a   $KIT_STAGE/step4.trc

    sleep 1

    if [ "$BL" = yes ]; then
     echo -e "    Special BladeLogic : aucun affichage ecran car trop volumineux.
     -----------------------------------------------------------------------------  "
     tar xjvf $DIRZIP/$ZIP  -C $ORACLE_HOME  2>&1 >> $KIT_STAGE/step4.trc
    else
     # ProgressBar:    https://stackoverflow.com/questions/238073/how-to-add-a-progress-bar-to-a-shell-script

     echo -e "    TarOneLine : Superposition des lignes (elargir la fenetre si besoin)
     -----------------------------------------------------------------------------  "
     tar xjvf $DIRZIP/$ZIP  -C $ORACLE_HOME  2>&1 | tee -a $KIT_STAGE/step4.trc  | awk '{printf("%79s\r=> %s\r" ," ",$0)}' 2>&1 1>/dev/tty
     fi

     # Client_19c     => 17813 lignes
     # Instant Client  19.23  198 lignes

     WCL_STEP4=`wc -l $KIT_STAGE/step4.trc | awk '{print $1}'`

     # Fourchette large pour eviter les problemes :

     if [ "$WCL_STEP4" -gt ${ZIP_NBFILES_MIN} -a "$WCL_STEP4" -lt ${ZIP_NBFILES_MAX} ]; then
          echo -e "\n   Extraction of the TAR seems OK [$WCL_STEP4 lines]."      ;  return  $RET_OK
     else
          echo -e "\n   Extraction of the TAR seems FAILED [$WCL_STEP4 lines]."  ;  return $RET_ERROR_UNTAR
     fi

#     #-------------------------------------------------
#     # CHMOD propose par Fred Brinquin mail du 25 avril 2017
#     # car il etait en 600 : ls -l | grep "w---"
#     # a confirmer et verifier si y'a d'autres fichiers dans ce cas
#     #-------------------------------------------------
#
#     chmod 644 $ORACLE_HOME/lib/libsqlplus.so


     #-------------------------------------------------
     # Check by the poll of 2 or 3 files :
     #-------------------------------------------------

     if [ -d $ORACLE_HOME/xdk  -a -d $ORACLE_HOME/precomp ]; then
     echo -e "
          The tar seems OK (according to the check of some files)."
     else
          echo -e "
          WARNING : some files are missing.
          Please check manually if unzip is good or not."
     fi

} # kit4_unzip

#=============================================================================

kit9a_uninstall_version()
{
echo -e "
#=======================================================================
# STEP_9a : Uninstall Version $ORACLE_HOME
#=======================================================================
"
        echo -e "
        ==============================================================
        Prerequisits :
          - $ORACLE_HOME must be not busy,
        ===============================================================
        "

     LSOF=$( lsof ${ORACLE_HOME} )
     if [[ ${LSOF} != "" ]]; then
          printf "\n\nThe filesystem \"${ORACLE_HOME}\" is busy:\n\n%s\n" "$LSOF"
          exit $RET_FS_BUSY
     fi

          kit_confirm || return $RET_STEP_ABORTED

     # 5_ Pas de uninstall pour cette partie.

     # 4_ Pas de nettoyage repertoires car le 2_ supprimera les FS.
     #    rm -fr  $ORACLE_HOME   # only if not in FS
     #    rm -fr  $ORACLE_BASE   # only if not in FS

     # 3_ Pas de Nettoyage de l'exploit :
     #     sera fait par 2_... uninstall_b et suppression User.

        kit2_volumes  uninstall_version      # Nettoyage FS, LV.

     # 1_ Pas de nettoyage de $KIT_STAGE ( /images/oracle/... )

} # kit9a_uninstall_version

#=============================================================================

kit9b_uninstall_account()
{
echo -e "
#=======================================================================
# STEP_9b : Uninstall The 'oracle' account ...
#=======================================================================
"
        echo -e "
        ===============================================================
        Prerequisits :
         - $ORACLE_HOME must be already UnInstalled,

     DANGEROUS : All versions of Oracle installed
              under $ORACLE_BASE will be lost.

         The user 'oracle' and the group 'dba' will be removed.
        ==============================================================="

          kit_confirm || return $RET_STEP_ABORTED

     if [ -f $ORACLE_HOME/bin/oracle ]
     then echo -e "
     The product $ORACLE_HOME/bin/oracle is still present.
     Abort (not removing the user 'oracle')." ; return $RET_STEP_ABORTED
     fi

     if [ -f $ORACLE_BASE/*/bin/oracle ]
     then echo -e "
     An other product Oracle ??? is still present.
     Abort (not removing the user 'oracle')." ; return $RET_STEP_ABORTED
     fi

        kit2_volumes  uninstall_account # clear User and Group

     kit3_operate  uninstall       # clear Operationg Tools

} # kit9b_uninstall_account

#=============================================================================

BANNER(){

     printf "\n\n==================================================\n"
     printf "%s (%s) v%s\n" "$SCRIPT_NAME_LONG" "$SCRIPT_NAME" "$SCRIPT_VERSION"

} # BANNER

#=============================================================================

#guess_icli_version()
## On essaie de deviner le numero de version, en fonction de la SIG et du bz2
## avant l'etape 0
## guess_icli_version VAR_SIG VAR_BZ2 
#
#{
#
#     VARNAME_SIG="$1"
#     VARNAME_BZ2="$2"
#     local ver_sig ver_bz2
#     
#     # test de la sig PA-ORA-I192300-RDG00R00C01.SIG
#     ver_sig=$( ls ./PA-ORA-I* 2>/dev/null)
#     [[ -z ${ver_sig} ]] && return
#     
#     # echo "ver_sig1='$ver_sig'"
#     ver_sig=$(basename $ver_sig)
#     # echo "ver_sig2='$ver_sig'"
#     ver_sig=${ver_sig%.*}
#     # echo "ver_sig3='$ver_sig'"
#     ver_sig=$(echo $ver_sig | sed "s/PA-ORA-I//g" )
#     # echo "ver_sig4='$ver_sig'"
#     ver_sig=${ver_sig%-*}
#     # echo "ver_sig5='$ver_sig'"
#     eval "${VARNAME_SIG}=\"$(echo "${ver_sig}")\""
#
#     # test du bz2 InstantClient_1923_RH.bz2
#     ver_bz2=$( ls -t ./*.bz2 | head -1 2>/dev/null)
#     [[ -z ${ver_bz2} ]] && return
#     
#     # echo "ver_bz21='$ver_bz2'"
#     ver_bz2=$(basename $ver_bz2)
#     # echo "ver_bz22='$ver_bz2'"
#     ver_bz2=${ver_bz2%.*}
#     # echo "ver_bz23='$ver_bz2'"
#     ver_bz2=$(echo $ver_bz2 | sed "s/InstantClient_//g" )
#     # echo "ver_bz24='$ver_bz2'"
#     ver_bz2=${ver_bz2%_*}
#     # echo "ver_bz25='$ver_bz2'"
#     eval "${VARNAME_BZ2}=\"$(echo "${ver_bz2}")\""
#
#
#} # guess_icli_version
#
##=============================================================================

USAGE () { 

     RET=${1:-0}
     # printf  "Usage: "$(basename $0)" -rRh -j <arg> file1 file2 \n\n"; 

     printf  "Usage: "$(basename $0)" [-h] [-s] [-y] [-k]\n\n"; 
     printf "     %-5s %-10s\n" "-h" "Help"
     printf "     %-5s %-10s\n" "-s" "Show variables"
     printf "     %-5s %-10s\n" "-k" "When creating the oracle user, make its shell ksh instead of bash by default"
     printf "     %-5s %-10s\n" "-y" "Answer \"yes\" to confirmation prompts"
     
     printf "\n"
     exit $RET
     
} # USAGE

#=============================================================================

# Interpretation de la ligne de commande
CLI_args()
{

     local do_show_vars=no do_show_help=no do_force_yes=no do_use_ksh=no
     
     # Command line arguments
     OPTIONS='hsyk'
     # echo -e "CLI=\"$@\""
     while getopts ${OPTIONS} optname; do

         case "${optname}" in
             # o  ) CLIENT_VERSION=$OPTARG
                  # . ./env_install_iclient.sh ${CLIENT_VERSION}
                  # ;;
             y  ) do_force_yes=yes;;
             s  ) do_show_vars=yes;;
             h  ) do_show_help=yes;;
             k  ) do_use_ksh=yes;;
             \? ) echo -e "Unknown option: -$OPTARG" >&2; USAGE 1;;
             :  ) "Missing option argument for -$OPTARG" >&2; USAGE 1;;
             *  ) echo -e "Unimplemented option: -${optname}" >&2; USAGE 1;;
         esac

     done

     [[ $do_show_vars = yes ]] && show_vars
     [[ $do_show_help = yes ]] && USAGE 0
     [[ $do_force_yes = yes ]] && FORCE_YES=yes
     [[ $do_use_ksh = yes ]] && USE_KSH=yes

     return  $RET_OK

} # CLI_args

#=============================================================================
#=============================================================================
#==============================  MAIN  =======================================
#=============================================================================
#=============================================================================

# Main

     BANNER
     FORCE_YES=no
     USE_KSH=no

     OS=`uname -s`
     if [ "$OS" != Linux ]; then
          echo -e "    ERROR : This script is made for Linux RedHat, not for [$OS]" ; exit $RET_WRONG_OS
     fi

     # Initialisation des variables
     . ./${SCRIPT_ENV_FILENAME}

     if ! CLI_args "$@"; then
          exit $?
     fi

#     # Si l'on est deja dans KIT_STAGE, on demande de lancer plutot le script avec le numero de version
#     # [[ $PWD = $KIT_STAGE ]] && echo "In KIT_STAGE" || echo "NOT In KIT_STAGE"
#     if [[ "$@" == *"current"* ]]; then 
#          [[ $DEBUG_LEVEL > 1 ]] && echo "YES current in CLI"
#          CURRENT_IN_CLI=1
#      else
#          [[ $DEBUG_LEVEL > 1 ]] && echo "NO current in CLI"
#          CURRENT_IN_CLI=0
#     fi
#     scrname="$SCRIPT_NAME"
#     scrfound=$(for i in `ls install_iclient*.sh`; do LEN=`expr length $i`; echo $LEN $i; done | sort -n | tail -1 )
#     scrfound=${scrfound#*' '}
#     echo "scrname=$scrname, scrfound=$scrfound"
#     # s'il existe un instant_client avec un filename plus long ET pas de "current" dans la CLI, on sort
#     if [ "$scrfound" != "$scrname" -a $CURRENT_IN_CLI -eq 0 ]; then
#          printf "\n\nUtilisez plutot le script avec me numero de version \"%s\"\n" "$scrfound"
#          exit $RET_USE_VERSIONED_SCRIPT
#     fi
#
#     # Si pas de version client:
#     if [[ $CLIENT_VERSION = "" ]]; then
#          printf "\n=======================================\n"
#          printf "\nThe instant client version is required.\n\n"
#          guess_icli_version VER_SIG VER_BZ2
#          printf "   Potential versions found:\n\tSIG shows '${VER_SIG}', the .bz2 (preferred) shows '${VER_BZ2}'\n"
#          printf "   *.env files found for versions:\n"
#          for file in $(find * -type f -name "*.env" ); do printf "\t%s\n" "${file%.*}"; done
#          printf "=======================================\n\n"
#          USAGE $RET_NO_CLIENT_VERSION
#     fi
     

     [ `echo '\r'` = '\r' ] && alias echo='echo -e'

     export OS LANG ORACLE_HOME
     VRH=$( get_version )

     case "$VRH" in

          7.*|8.*|9.* ) RH=${VRH/./}; #printf "\n\n     Oracle Instant Client ${VERSDOT} on RedHat $VRH, will be installed in '${ORACLE_HOME}'\n\n"
                    ;;
          *   ) echo -e "     This Oracle kit is not made for RedHat $VRH"      ; exit $RET_WRONG_OS  ;;
     esac

     case "$VRH" in
          # 6.*  ) FSTYP=ext4 ; WIPE=""     ; THP=enabled_from_platon   ;;  # THP will be disabled in this kit.
          7.*  ) FSTYP=ext4 ; WIPE="-W n" ; THP=disabled_from_platon  ;;  # THP OK : nothing to do.
          8.*  ) FSTYP=xfs  ; WIPE="-W n" ; THP=disabled_from_platon  ;;  # THP OK : nothing to do.
          9.*  ) FSTYP=xfs  ; WIPE="-W n" ; THP=disabled_from_platon  ;;  # THP OK : nothing to do.
     esac

     # KIT_STAGE_TRC=${KIT_STAGE}/STEP_RH$RH.REF
     # [[ $DEBUG_LEVEL > 0 ]] && printf "\n\n Creating dir $KIT_STAGE_TRC\n\n\n"
     # mkdir -p $KIT_STAGE_TRC #2>/dev/null

     if [ "$2" = confirm ]; then 
          :              # si Confirm, alors on skip l'affichage de cette baniere.
     else
          
          TITRE="Oracle Instant Client ${VERSDOT} on Linux RedHat ${VRH}"
     echo -e "

     |====== $TITRE =======
     |
     |  Will be installed in '$ORACLE_HOME'
     |
     |=============================================================="
     fi


     LISTRC=`ls -1 step[0-4].trc 2>/dev/null | cut -c5 2>/dev/null`
     LISTRC=`echo $LISTRC`


     #  CONFIRM_STEP         for the start of each step.
     #  CONFIRM_AUTO         for the list of ORDERS in step 2 and 9a.
     #  CONFIRM_FORCE        for some cases that are abnormal but sometimes allowed

#   # Pour lancer des steps en ligne de commande, a refaire avec getopts
#    case "$1" in
#         step[0-5]|step9a|step9b )
#              STEP=${1#step}
#              [ "$2" = confirm ] &&  CONFIRM_STEP=yes && CONFIRM_AUTO=yes
#              ;;
#         * )  case "$OS" in
#                   Linux ) LIBELLE_STEP1="Check and Add Linux RPMs" ;;
#                   AIX   ) LIBELLE_STEP1="STEP EMPTY for AIX : Nothing to do."   ;;
#    esac

     case "$OS" in
         Linux ) LIBELLE_STEP1="Check and Add Linux RPMs" ;;
         AIX   ) LIBELLE_STEP1="STEP EMPTY for AIX : Nothing to do."   ;;
     esac

     echo -e "     |
     |    0  Copy some files from KIT to $KIT_STAGE
     |      ----------------------
     |       => cd $KIT_STAGE ; then continue :
     |         ----------------------
     |    1  <><>   $LIBELLE_STEP1
     |    2  <><><>   Install Group + User + LV + FS
     |    3  <><><><>   Install Operating scripts
     |    4  <><><><><>   Unzip for ZIP file
     |
     |    9a !!  Uninstall Oracle Version $ORACLE_HOME"
     # |    9b !!!!  Uninstall Oracle Account and all Versions
     echo  -e "     |
     |==============================================================
     |   Existing Traces    : $LISTRC
     |   Follow these steps : 0 1 2 3 4 9a (q) ? \c"
          read STEP
#          ;;
#     esac


     [ `id -un` = root ] || { echo -e "    You must be root." ; exit $RET_MUST_BE_ROOT ; }

     case "$STEP" in
          [1-9]* )  if [ `pwd` != $KIT_STAGE ]; then 
                         echo -e "     ERROR - For steps [1,2,3,4,5] ; You must be in $KIT_STAGE"
                         exit $RET_MUST_BE_IN_STAGE
                    fi ;;
     esac

     case "$SPEP" in
          1) [ "$LISTRC" = "0" ]         || STEP_UNEXPECTED=yes ;;
          2) [ "$LISTRC" = "0 1" ]       || STEP_UNEXPECTED=yes ;;
          3) [ "$LISTRC" = "0 1 2" ]     || STEP_UNEXPECTED=yes ;;
          4) [ "$LISTRC" = "0 1 2 3" ]   || STEP_UNEXPECTED=yes ;;
     esac

     if [ "$STEP_UNEXPECTED" = yes ]; then 
          echo -e "    Existing traces are : $LISTRC"
          echo -e "    Confirm step $STEP (yes/no) : \c"
          read CONFIRM_FORCE
          [ "$CONFIRM_FORCE" = yes ] || { echo -e "  Abort." ; exit $RET_OK ; }
     fi

     mv $KIT_STAGE/step$STEP.trc $KIT_STAGE/step$STEP.old 2>/dev/null

    case "$STEP-$OS" in
          0-*    ) (kit0_copy               || echo -e "EcHeC" ) 2>&1 | tee /tmp/step0.trc
                                            mv /tmp/step0.trc $KIT_STAGE ;;
          1-Linux) (kit1_rpm                || echo -e "EcHeC" ) 2>&1 | tee $KIT_STAGE/step1.trc  ;;
          1-AIX  ) (echo -e "$LIBELLE_STEP1"   || echo -e "EcHeC" ) 2>&1 | tee $KIT_STAGE/step1.trc  ;;
          2-*    ) (kit2_volumes install    || echo -e "EcHeC" ) 2>&1 | tee $KIT_STAGE/step2.trc  ;;
          3-*    ) (kit3_operate install    || echo -e "EcHeC" ) 2>&1 | tee $KIT_STAGE/step3.trc  ;;
          4-*    ) (kit4_unzip              || echo -e "EcHeC" ) 2>&1 | tee $KIT_STAGE/step4.trc  ;;
          9a-*   ) (kit9a_uninstall_version || echo -e "EcHeC" ) 2>&1 | tee $KIT_STAGE/step9a.trc ;;
#          9b-*   )
#                    # For the removal of links in /opt/operating/bin ...
#                    DIRSAV=`pwd`
#                    cd $KIT_STAGE/FT180
#                    ./instora_FT180.ksh uninstall
#                    cd $DIRSAV
#                    (kit9b_uninstall_account  || echo -e "EcHeC" ) 2>&1 | tee $KIT_STAGE/step9b.trc
#                    ;;

          ""-*|q-*|Q-* ) echo -e " Exit." ; exit $RET_OK;;
          * ) echo -e "$0 : Choice [$STEP] is not proposed." ; exit $RET_WRONG_STEP ;;
              
     esac

     # cp -f $KIT_STAGE/step$STEP.trc $KIT_STAGE_TRC/
     echo -e "\n        Trace : $KIT_STAGE/step$STEP.trc\n"

     mkdir -p $KIT_REPOS
     cp -p $KIT_STAGE/step$STEP.trc  $KIT_REPOS/install_oracle_iclient_${VERSNUM}_step${STEP}_`date +"%Y%m%d_%H%M"`.log

     if [ -r $KIT_STAGE/step$STEP.trc ]; then 
          :    # Trace found : the next check can occur.
     else 
          echo -e "     Error : Trace $KIT_STAGE/step$STEP.trc not found or not readable !"
          exit $RET_CANNOT_SRITE_TRACE
     fi

     if [ `grep -c "^EcHeC$" $KIT_STAGE/step$STEP.trc` = 0 ]; then 
          exit $RET_OK
     else  
          exit $RET_KO
     fi

#=============================================================================
# fin
