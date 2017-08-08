#!/bin/bash
#set -x

########
#
#  Systeme alterne V2.0
#
########



message () {
        ksh ${SYSALTPATH}/sysalt_message.ksh  $2 "$3"
}


# Fonction terminer_ko
terminer_ko() {
        message "*** FIN ECHEC"
        \rm /var/run/${PROG}.pid
        exit 2
}

# FQT Fonction nom_clone
nom_clone() {
  if echo $1 | grep '_alt$' >/dev/null 2>&1; then
    echo $1 | sed 's/_alt$//'
  else
    echo ${1}_alt
  fi
}



# Fonction grub_avec_sys_alt
# --------------------------
grub_avec_sys_alt()
{
  # ----------------------------------------------------------------------------
  # Dans le fichier de configuration GRUB, recherche et duplique les 'entrees'
  # pointant vers le nom BIOS du disk source (${bios_disk_source}) en effectuant
  # les modifications suivantes sur les 'entrees' dupliquees :
  # - ajout de "[Systeme Alterne]" a la fin du titre
  # - remplacement du nom BIOS du disk source (${bios_disk_source}) par le
  #   nom BIOS du disk clone (${bios_disk_clone})
  # - remplacement de la chaine "root=LABEL=/" par la chaine
  #   "root=LABEL=/_alt"
  # ----------------------------------------------------------------------------

  flag_error=0
  # FQT fic_tempo0 contient les lignes de FIC_CONFGRUB a ne pas dupliquer
  fic_tempo0="/tmp/sys_alt.grub0"
  fic_tempo1="/tmp/sys_alt.grub1"
  fic_tempo2="/tmp/sys_alt.grub2"
  fic_tempo1_alt="/tmp/sys_alt.grub1.alt"
  fic_tempo2_alt="/tmp/sys_alt.grub2.alt"


  message -m SYSTEME_ALTERNE_I "Ajout eventuel des entrees [Systeme Alterne] dans le fichier : ${FIC_CONFGRUB}"

  # FQT Creation du fichier temporaire (${fic_tempo0))
  # --------------------------------------------------
  /bin/awk '
    $1 == "title"  { next }
    $1 == "root"   { next }
    $1 == "kernel" { next }
    $1 == "initrd" { next }
    { print }
    ' "${FIC_CONFGRUB}" > ${fic_tempo0}
  cr1=$?

  if [ "${DEBUG}" = "1" ]
  then
    echo "---------------------------------------------------"
    echo "Contenu du fichier travail genere (${fic_tempo0}) contenant les 'entrees' a ne pas dupliquer :"
    cat "${fic_tempo0}"
    echo "---------------------------------------------------"
  fi

  # Creation 1er fichier temporaire (${fic_tempo1}) :
  # constitution des 'entrees' concernant ${bios_disk_source} que l'on va dupliquer
  # -------------------------------------------------------------------------------
  grep -v "^#" ${FIC_CONFGRUB} | \
  awk -v var=${bios_disk_source} '{
    if ( $1 == "title" ) lig_title=$0
    if ( $1 == "root"   ) lig_root=$0
    if ( $1 == "kernel" ) lig_kernel=$0
    if ( $1 == "initrd" ) lig_initrd=$0

    if ( $1 == "initrd" )
    {
      if ( index(lig_root,var) != 0 )
      {
        print lig_title
        print lig_root
        print lig_kernel
        print lig_initrd
      }
    }
    }' >${fic_tempo1}



  cr1=$?

  if [ "${DEBUG}" = "1" ]
  then
    echo "---------------------------------------------------"
    echo "Contenu du fichier travail genere (${fic_tempo1}) contenant les 'entrees' a dupliquer :"
    cat ${fic_tempo1}
	echo ${bios_disk_source}
    echo "---------------------------------------------------"
  fi

# pour le le systeme clone
sed -e 's/hd0/hd1/'  ${fic_tempo1} > ${fic_tempo1_alt}


  if [ "${DEBUG}" = "1" ]
  then
    echo "---------------------------------------------------"
    echo "Contenu du fichier travail genere (${fic_tempo1}) contenant les 'entrees' a dupliquer 2 :"
    cat ${fic_tempo1}
    echo "---------------------------------------------------"
  fi



  # Creation 2d fichier temporaire (${fic_tempo2}) :
  # modifications des 'entrees' retenues
  # ------------------------------------------------
  args_pour_le_sed="s/${bios_disk_source}/${bios_disk_clone}/"

  # FQT Le disque source est'il le disque alterne ?
  # le fichier $fic_tempo1 contient il la chaine
  # "title .* [Systeme Alterne]" ?
  # -----------------------------------------------
  if grep "^[[:space:]]*title[[:space:]].*\[Systeme Alterne\]" ${fic_tempo1} >/dev/null 2>&1
  then
    sed -e "${args_pour_le_sed}" \
        -e 's/^\([[:space:]]*title[[:space:]].*\)[[:space:]]*\[Systeme Alterne\]/\1/
            s/\(root=LABEL=[^[:space:]]*\)_alt/\1/
            s#root=/dev/\([^[:space:]]*\)_alt/\([^[:space:]]*\)_alt#root=/dev/\1/\2#
                s#rd_LVM_LV=\([^[:space:]]*\)_alt/\([^[:space:]]*\)_alt#rd_LVM_LV=\1/\2#g
                        s#root=/dev/mapper/\([^[:space:]]*\)_alt\([^[:space:]]*\)_alt#root=/dev/mapper/\1\2#
            s/\(initrd\)[[:space:]]*\(.*\)_ALT/\1 \2/' ${fic_tempo1} > ${fic_tempo2}
    cr2=$?
  else
    sed ${args_pour_le_sed} ${fic_tempo1} | \
    awk '{
      if ( $1 == "title" )
      {
        print $0 " [Systeme Alterne]"
      }
      else
      {
        print $0
      }
      }' | \
	sed -e 's/\(root=LABEL=[^[:space:]]*\)/\1_alt/
		s#root=/dev/\(.*\)/\([^ ]*\)#root=/dev/\1_alt/\2_alt#
		s#root=/dev/mapper/\([^[:space:]]*\)-\([^[:space:]]*\)#root=/dev/mapper/\1_alt-\2_alt#
		s#rd_LVM_LV=\([^[:space:]]*\)/\([^[:space:]]*\)#rd_LVM_LV=\1_alt/\2_alt#
		s/\(initrd[^ \\t]*\)\(.*\)[^ \\t]*$/\1 \2_ALT/'  >${fic_tempo2}

    cr2=$?
  fi

sed -e 's/hd1/hd0/'  ${fic_tempo2} > ${fic_tempo2_alt}


for INITRDFILE in `grep "^[[:space:]]*initrd[[:space:]].*_ALT[[:space:]]*$"   ${fic_tempo2} | sed "s/.*initrd.*\///;s/.img.*//"
`
do
        # la variable d'environnement GZIP gene la compression
        # (declare dans /outillage/glob_par/config_systeme.env)
        unset GZIP
        INITR=`echo $INITRDFILE    | cut  -d'-' -f1`
        KERNEL=`echo $INITRDFILE    | cut  -d'-' -f2-6`
        mkinitrd -f /boot/${INITR}-${KERNEL}.img_ALT ${KERNEL} --fstab="${RACINE_SYS_ALT}${FIC_FSTAB}"
        cp -a /boot/${INITR}-${KERNEL}.img_ALT ${RACINE_SYS_ALT}/boot/
	
done

for INITRDFILE in `grep "^[[:space:]]*initrd[[:space:]]"   ${fic_tempo2} | grep -v "_ALT[[:space:]]*$" | sed "s/.*initrd.*\///;s/.img.*//"
`
do
        # la variable d'environnement GZIP gene la compression
        # (declare dans /outillage/glob_par/config_systeme.env)
        unset GZIP
        INITR=`echo $INITRDFILE    | cut  -d'-' -f1`
        KERNEL=`echo $INITRDFILE    | cut  -d'-' -f2-6`
        mkinitrd -f /boot/${INITR}-${KERNEL}.img ${KERNEL} --fstab="${RACINE_SYS_ALT}${FIC_FSTAB}"
        cp -a /boot/${INITR}-${KERNEL}.img ${RACINE_SYS_ALT}/boot/
	
done




####

  if [ "${DEBUG}" = "1" ]
  then
    echo "---------------------------------------------------"
    echo "Lignes a ajouter dans le fichier ${FIC_CONFGRUB} :"
    cat ${fic_tempo2}
    echo "---------------------------------------------------"
  fi

  if [ ${cr1} -ne 0 -o ${cr2} -ne 0 ]
  then
    message  -m SYSTEME_ALTERNE_E "Erreur lors de la preparation des modifications dans ${FIC_CONFGRUB}"
    flag_error=1
  else

    # Ajout des nouvelles 'entrees' dans le fichier de configuration GRUB
    # -------------------------------------------------------------------
    for lig in $(grep title ${fic_tempo2} | sed 's/ /_/g')
    do
      message -m SYSTEME_ALTERNE_I  "Ajout entree '${lig}'"
    done

    # FQT Le contenu du fichier fic_tempo2 doit etre avant celui de fic_tempo1
    # si fic_tempo1 contient une ligne concernant le systeme alterne
    # ------------------------------------------------------------------------
    if grep "^[[:space:]]*title[[:space:]].*\[Systeme Alterne\]" ${fic_tempo1} >/dev/null 2>&1
    then
      cat ${fic_tempo0} ${fic_tempo2} ${fic_tempo1} > ${FIC_CONFGRUB}
    else
      cat ${fic_tempo0} ${fic_tempo1} ${fic_tempo2} > ${FIC_CONFGRUB}
    fi

    if [ $? -ne 0 ]
    then
      message -m SYSTEME_ALTERNE_E  "Erreur lors de l'ajout des 'entrees' dans ${FIC_CONFGRUB}"
      flag_error=1
    fi

    # FQT Ne pas oublier de mettre a jour le fichier
    # de configuration GRUB sur le disque clone
    # ----------------------------------------------
    if grep "^[[:space:]]*title[[:space:]].*\[Systeme Alterne\]" ${fic_tempo1} >/dev/null 2>&1
    then
      cat ${fic_tempo0} ${fic_tempo2_alt} ${fic_tempo1_alt} > ${RACINE_SYS_ALT}${FIC_CONFGRUB}
    else
      cat ${fic_tempo0} ${fic_tempo1_alt} ${fic_tempo2_alt} > ${RACINE_SYS_ALT}${FIC_CONFGRUB}
    fi

    if [ $? -ne 0 ]
    then
      message -m SYSTEME_ALTERNE_E  "Erreur lors de la copie de ${FIC_CONFGRUB} dans ${RACINE_SYS_ALT}${FIC_CONFGRUB}"
      flag_error=1
    fi


  fi

  chmod 644 ${FIC_CONFGRUB}
  # FQT
  chmod 644 ${RACINE_SYS_ALT}${FIC_CONFGRUB}
  rm -f ${fic_tempo1} ${fic_tempo2} ${fic_tempo1_alt} ${fic_tempo2_alt}
  unset fic_tempo1 fic_tempo2 cr1 cr2 args_pour_le_sed lig



#echo "clone source est $CLONE_SOURCE"

# Nouvell methode d install de grub
if [ $CLONE_SOURCE == 0 ]
then
hdalt="hd0"
message -m SYSTEME_ALTERNE_I  "systeme original, install grub sur HD1"
else
hdalt="hd0"
message -m SYSTEME_ALTERNE_I  "systeme alterne, install grub sur HD0"
fi

/sbin/grub --batch --no-floppy --device-map=/boot/grub/device.map  >/dev/null 2>&1 << EOF
root ($hdalt,0)
setup ($hdalt)
quit
EOF

  return ${flag_error}
}






# Fonction grub_sans_sys_alt
# --------------------------
grub_sans_sys_alt()
{
  # --------------------------------------------------------------------
  # Dans le fichier de configuration GRUB, supprime toutes les 'entrees'
  # pointant vers le nom BIOS du disk clone (${bios_disk_clone}).
  # --------------------------------------------------------------------

  flag_error=0
  fic_tempo1="/tmp/sys_alt.grub1"

  message  -m SYSTEME_ALTERNE_I "Suppression eventuelle des entrees [Systeme Alterne] dans le fichier : ${FIC_CONFGRUB}"

  awk -v var=${bios_disk_clone} '{
    if ( $1 == "title" )
    {
      lig_title=$0
    }
    else
    {
      if ( $1 == "root" )
      {
        lig_root=$0
      }
      else
      {
        if ( $1 == "kernel" )
        {
          lig_kernel=$0
        }
        else
        {
          if ( $1 == "initrd" )
          {
            lig_initrd=$0
          }
          else 
          {
            print $0
          }
        }
      }
    }
    if ( $1 == "initrd" )
    {
      if ( index(lig_root,var) == 0 )
      {
        print lig_title
        print lig_root
        print lig_kernel
        print lig_initrd
      }
    }
    }' ${FIC_CONFGRUB} >${fic_tempo1}
  cr=$?

  if [ "${DEBUG}" = "1" ]
  then
    echo "---------------------------------------------------"
    echo "Contenu du fichier travail genere (${fic_tempo1}) qui va remplacer ${FIC_CONFGRUB} :"
    cat ${fic_tempo1}
    echo "---------------------------------------------------"
  fi

  if [ ${cr} -ne 0 ]
  then

    message  -m SYSTEME_ALTERNE_E  "Erreur lors de la preparation des modifications dans ${FIC_CONFGRUB}"
    flag_error=1

  else

    mv -f ${fic_tempo1} ${FIC_CONFGRUB}
    if [ $? -ne 0 ]
    then
      message  -m SYSTEME_ALTERNE_E  "Erreur lors du renommage de ${fic_tempo1} en ${FIC_CONFGRUB}"
      flag_error=1
    fi

  fi

  chmod 644 ${FIC_CONFGRUB}
  unset fic_tempo1 cr

  return ${flag_error}
}



update_clone_grub () {
# ====================================================================================================
message  -m SYSTEME_ALTERNE_I  "MISE A JOUR DES ENTREES [Systeme Alterne] DANS LA CONFIGURATION DE GRUB"
# ====================================================================================================
# -------------------------------------------------------------------------------
# Pour etre sur que les 'entrees' vers le systeme alterne (c'est a dire celles
# pointant vers le nom BIOS du disk clone (${bios_disk_clone}) soient bien a jour
# par rapport a celles pointant vers le systeme source (c'est a dire celles
# pointant vers le nom BIOS du disk source (${bios_disk_source}),
# on commence par supprimer toutes les entrees vers le systeme alterne puis on
# les recree
# -------------------------------------------------------------------------------


# Suppression des 'entrees' vers systeme alterne
# ----------------------------------------------
grub_sans_sys_alt

if [ $? -ne 0 ]
then
  terminer_ko
else

  # Recreation des 'entrees' vers systeme alterne
  # ---------------------------------------------
  
 grub_avec_sys_alt
  if [ $? -ne 0 ]
  then
    terminer_ko
  fi
fi
# ===============================================
# update_clone_grub
# ===============================================
}



create_clone_fstab () {
# ==================================================================================
message  -m SYSTEME_ALTERNE_I "RECONSTRUCTION DE ${FIC_FSTAB} SUR LE SYSTEME ALTERNE"
# ==================================================================================

# Definition nom complet du fichier "/etc/fstab" sur le systeme alterne
# (il est donc localise sous ${RACINE_SYS_ALT})
# ---------------------------------------------------------------------
fstab_clone="${RACINE_SYS_ALT}${FIC_FSTAB}"

message  -m SYSTEME_ALTERNE_I "Nom complet du fichier modifie : ${fstab_clone}"

if [ ! -s "${fstab_clone}" ]
then
	message  -m SYSTEME_ALTERNE_E  "Fichier ${fstab_clone} absent ou vide"

	demontage_fs_clone
	grub_sans_sys_alt
	terminer_ko
fi

i=0
if [ ! "${nb_lv}" ]; then
	nb_lv=${#lv_clone_name[*]}
fi

let nb_part_total=${nb_part}+${nb_lv}
while [ ${i} -lt ${nb_part_total} ]
do
	let i=$i+1
	case ${typ_part[$i]} in
		'82' )
			rename_fs_fstab_clone ${i}
		;;
		'83' )
			rename_fs_fstab_clone ${i}
		;;
		* )
			# Seules les partitions de type '82' ou '83' sont concernees par /etc/fstab
			# les autres partitions sont ignorees
			#
			#echo "==== typ_part[$i]=${typ_part[$i]} == part_src[$i]=${part_src[$i]} == part_clone[$i]=${part_clone[$i]} == label_part[$i]=${label_part[$i]}"
		;;
	esac
done

# remise en place des droits sur le fichier, par precaution
# ---------------------------------------------------------
chmod 644 ${fstab_clone}

unset fstab_clone cr1 cr2
#============================================================
#    fIN create_clone_fstab
# ===========================================================
}

rename_fs_fstab_clone () {
# Recherche du filesystem, par le nom de sa partition,
# et le cas echeant, remplacement par le nom de la partition clone
# ----------------------------------------------------------------

if [ ! "${vg_src}" ]
then
	vg_src=${vgroot}
fi
vg_clone="$(nom_clone $vg_src)"
#echo "typ_part[$i]=${typ_part[$i]} ===== part_src[$i]=${part_src[$i]} ===== typ_fs[$i]=${typ_fs[$i]} ==== ptm_fs[$i]=${ptm_fs[$i]}"
i=$1
case ${part_src[$i]} in
	/dev/${vg_src}/* )
		lv_name=$(echo ${part_src[$i]}|awk -F"/" '{print $NF }')
		lv_clonename="$(nom_clone $lv_name)"  
		TEMP_I=${i}
		message   -m SYSTEME_ALTERNE_I "Remplacement de /dev/mapper/${vg_src}-$lv_name par /dev/mapper/${vg_clone}-$lv_clonename"
		i=${TEMP_I}
		sed -e "s#\(^/dev/mapper/\)${vg_src}-\(${lv_name}.*$\)#\1${vg_clone}-\2#g;s#\(^/dev/\)${vg_src}/\(${lv_name}.*$\)#\1${vg_clone}/\2#g" ${fstab_clone} >${fstab_clone}.tmp
		sed -i -e "s#\(^/dev/.*${vg_clone}[/-]\)${lv_name}[[:space:]]\(.*$\)#\1${lv_clonename} \2#g" ${fstab_clone}.tmp
		cr1=$?
		mv -f ${fstab_clone}.tmp ${fstab_clone}
		cr2=$?
	;;
	${disk_source}* )
		if [ $(awk -v var=${part_src[$i]} '{ if ( $1 == var ) print $0 }' ${fstab_clone} | wc -l) -eq 1 ]
		then
			#MODIF KSH93 de rhel6
			TEMP_I=${i}
			message   -m SYSTEME_ALTERNE_I "Remplacement de ${part_src[$i]} par ${part_clone[$i]}"
			i=${TEMP_I}
			#set -x
			#echo "=========== 83 ps=${part_src[$i]} pc=${part_clone[$i]} ======================="
			awk -v ps="${part_src[$i]}" -v pc="${part_clone[$i]}" '{
				if ( $1 == ps )
				{
					a=( length($1) + 1 )
					printf("%s%s\n",pc,substr($0,a))
				}
				else
				{
					print $0
				}
				}' ${fstab_clone} >${fstab_clone}.tmp

			cr1=$?

			if [ "${DEBUG}" = "1" ]
			then
				echo "---------------------------------------------------"
				echo "Contenu du fichier ${fstab_clone} avant modification :"
				cat ${fstab_clone}
			fi

			mv -f ${fstab_clone}.tmp ${fstab_clone}
			cr2=$?

			if [ "${DEBUG}" = "1" ]
			then
				echo "---------------------------------------------------"
				echo "Contenu du fichier ${fstab_clone} apres modification :"
				cat ${fstab_clone}
				echo "---------------------------------------------------"
			fi

			if [ ${cr1} -ne 0 -o ${cr2} -ne 0 ]
			then
				message  -m SYSTEME_ALTERNE_E "Erreur lors de la modification du fichier ${fstab_clone}"

				demontage_fs_clone
				grub_sans_sys_alt
				terminer_ko
			fi
			#set +x
		else
			# Sinon, recherche du filesystem, par son LABEL,
			# et le cas echeant, remplacement par le LABEL de la partition clone
			# ("<label_partition_source>_alt")
			# 
			# ------------------------------------------------------------------  
			#part_src_mapper=$(echo "${part_src[$i]}"|sed "s#/dev/#/dev/mapper/#"|sed "s#/dev/mapper/\(.*\)/\(.*\)#/dev/mapper/\1-\2#")
			#echo "======== part_src[$i]=${part_src[$i]} ======== label_part[$i]=${label_part[$i]} ======= part_src_mapper=$part_src_mapper ====================="
			if [ $(awk -v var=${label_part[$i]} '{ if ( $1 == "LABEL="var ) print $0 }' ${fstab_clone} | wc -l) -eq 1 ]
			then
				# FQT
				label_part_alt=$(nom_clone ${label_part[$i]})
				TEMP_I=${i}
				message   -m SYSTEME_ALTERNE_I "Remplacement de LABEL=${label_part[$i]} par LABEL=${label_part_alt}"
				i=${TEMP_I}

				# FQT
				#awk -v ls="${label_part[$i]}" '{
				awk -v ls="${label_part[$i]}" -v lc="${label_part_alt}" '{
					if ( $1 == "LABEL="ls )
					{
						a=( length($1) + 1 )
						# FQT
						#printf("LABEL=%s_alt%s\n", ls, substr($0,a))
						printf("LABEL=%s%s\n", lc, substr($0,a))
					}
					else
					{
						print $0
					}
				}' ${fstab_clone} >${fstab_clone}.tmp
				cr1=$?

				if [ "${DEBUG}" = "1" ]
				then
					echo "---------------------------------------------------"
					echo "Contenu du fichier ${fstab_clone} avant modification :"
					cat ${fstab_clone}
				fi

				mv -f ${fstab_clone}.tmp ${fstab_clone}
				cr2=$?

				if [ "${DEBUG}" = "1" ]
				then
					echo "---------------------------------------------------"
					echo "Contenu du fichier ${fstab_clone} apres modification :"
					cat ${fstab_clone}
					echo "---------------------------------------------------"
				fi

				if [ ${cr1} -ne 0 -o ${cr2} -ne 0 ]
				then
					message  -m SYSTEME_ALTERNE_E "Erreur lors de la modification du fichier ${fstab_clone}"

					demontage_fs_clone
					grub_sans_sys_alt
					terminer_ko
				fi

			else
				#MODIF RHEL6 partition de /boot utilise UUID du device
				if [ $($GREP "^UUID=" $FIC_FSTAB|wc -l) -eq 1 ]
				then
					TROUVE=$($AWK -v PTM=${ptm_fs[$i]} '$1~/^UUID=/ && $2==PTM' $FIC_FSTAB |wc -l)
					if [ $TROUVE -ge 1 ]
					then
						UUID_source=$(/sbin/tune2fs -l ${part_src[$i]}|awk 'NF==3 && $0~/^Filesystem UUID:/ { print $3 }')
						UUID_clone=$(/sbin/tune2fs -l ${part_clone[$i]}|awk 'NF==3 && $0~/^Filesystem UUID:/ { print $3 }')
						TEMP_I=${i}
						message   -m SYSTEME_ALTERNE_I  "Remplacement de UUID_source=${UUID_source} par UUID_alt=${UUID_clone}"
						i=${TEMP_I}
						$AWK -v UUID_source=${UUID_source} -v UUID_clone=${UUID_clone} '
							$0~UUID_source {sub(UUID_source,UUID_clone,$0) ;print $0 ;next}
							{ print $0 }
							' ${fstab_clone} >${fstab_clone}.tmp
						mv -f ${fstab_clone}.tmp ${fstab_clone}
					else
						TEMP_I=${i}
						message  -m SYSTEME_ALTERNE_W  "ATTENTION: le filesystem correspondant a la partition ${part_src[$i]}"
						message  -m SYSTEME_ALTERNE_W  "n'a pas ete trouve dans ${fstab_clone}, pas de mise a jour sur le systeme alterne"
						i=${TEMP_I}
						FLAG_ERROR=1
					fi
				fi
			fi
		fi
	;;
	* )
		echo "Partition ${part_src[$i]} non trouve dans la fstab"
	;;
esac

}



copy_source_to_clone () {
	point_montage_alterne=$2
	racine_sys_alt=$1

	cd ${point_montage_alterne}
	if [ $? -ne 0 ]
	then
		message  -m SYSTEME_ALTERNE_E "Erreur lors du deplacement dans ${point_montage_alterne}"

		demontage_fs_clone
		grub_sans_sys_alt
		terminer_ko
	fi

  # Lancement de la copie des fichiers avec cpio
  # --------------------------------------------
  if [ "${DEBUG}" = "1" ]
  then
    echo "---------------------------------------------------"
    echo "COMMANDE EXECUTEE:"
    echo "find . -xdev | ( cpio -ocvB | ( cd ${racine_sys_alt}${point_montage_alterne} ; cpio -icvdumB ) )"
    echo "---------------------------------------------------"

    # CTE : la sortie de cette commande est redirigee vers /dev/null pour eviter un fichier de log
    # important lorsque, en mode debug, la sortie de systeme_alterne.ksh est redirige vers un
    # fichier de sortie
    # pour un mode debug complet, supprimer la redirection standard et erreur vers /dev/null
    # de la commande ci-dessous

    find . -xdev | ( cpio -ocvB | ( cd ${racine_sys_alt}${point_montage_alterne} ; cpio -icvdumB ) )
    cr=$?

  else

    find . -xdev | ( cpio -ocvB | ( cd ${racine_sys_alt}${point_montage_alterne} ; cpio -icvdumB ) ) >/dev/null 2>&1
    cr=$?

  fi
  # on garde les permissions originelles
  perm=`stat -c%a ${point_montage_alterne}`
  chmod $perm  ${racine_sys_alt}${point_montage_alterne}


  if [ ${cr} -ne 0 ]
  then
    message   -m SYSTEME_ALTERNE_E "Erreur lors de la copie des fichiers du filesystem sur ${point_montage_alterne}"
    message   -m SYSTEME_ALTERNE_E "Commande en echec: find . -xdev | ( cpio -ocvB | ( cd ${racine_sys_alt}${point_montage_alterne} ; cpio -icvdumB ) )"
    demontage_fs_clone
    grub_sans_sys_alt
    terminer_ko
  fi

  if [ "${DEBUG}" = "1" ]
  then
    echo "nbre de fichiers sur FS source ${point_montage_alterne}:"
    find ${point_montage_alterne} -xdev | wc -l

    echo "nbre de fichiers sur FS clone ${racine_sys_alt}${point_montage_alterne}:"
    find ${racine_sys_alt}${point_montage_alterne} -xdev | wc -l
    echo "---------------------------------------------------"
  fi



# ==================================================
# Fin copy_source_to_clone
# ==================================================
}



# Fonction controle_mount_point
controle_mount_point() {
  # --------------------------------------------------------------------------
  # Contole l'existance des points de montage:
  # Retoune une premiere chaine de caracteres constituee de la partie existante
  # du point de montage et une seconde constituee de la partie inexistante
  # du point de montage qui sera a creer.
  # --------------------------------------------------------------------------
  PATH_FULL=$1

  while echo ${PATH_FULL} | grep '//'>/dev/null 2>&1; do
    PATH_FULL=$( echo ${PATH_FULL} | sed 's/\/\//\//g' )
  done

  echo "${PATH_FULL}" | grep "^/" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo  -m SYSTEME_ALTERNE_E "Erreur le point de montage ${PATH_FULL} ne commence pas par '/' "
    return 1
  fi

  PATH_FULL=$( echo "${PATH_FULL}" | sed "s/\/[ \t]*$//" )

  IFS_SAV="$IFS"
  IFS="/"
  set -a PATH_PART $1
  IFS=${IFS_SAV}

  cd /
  PATH_PRESENT="/"
  PATH_LOST=""
  i=1
  while [ $i -lt ${#PATH_PART[*]} ]; do
    if [ ! -d ${PATH_PART[$i]} ]; then
      print "${PATH_PRESENT}" "${PATH_FULL#$PATH_PRESENT}"
      return 0
    fi
    cd ${PATH_PART[$i]}
    PATH_PRESENT=${PATH_PRESENT}${PATH_PART[$i]}"/"
    (( i++ ))
  done
  #echo ${PATH_PRESENT} ""
  return 0
}


demontage_fs_clone() {
  # --------------------------------------------------------------------------
  # Pour tous les FS clones a demonter, et afin de les demonter du plus bas au
  # plus haut dans l'arborescence,
  # Constitution d'un fichier de travail temporaire avec les champs suivants :
  # - longueur de la chaine de caracteres correspondante au point de montage
  # - nom de la partition clone correspondante
  # Tri de ce fichier sur la longueur de la chaine (de la plus longue a la
  # plus courte).
  # Puis demontage de tous les FS presents dans ce fichier.
  # --------------------------------------------------------------------------
  #  set -x
  fic_table="/tmp/table_fs.$(basename ${disk_clone}).$$"
  >${fic_table}

typeset -i i
i=0
while [ ${i} -lt ${nb_part} ]
do
  i=$i+1
  if [ "${typ_part[$i]}" = "83" ]
  then
    if [ $(mount | egrep "^${part_src[$i]}[[:space:]]|^$(echo ${part_src[$i]} | sed "s/dev/dev\/mapper/;s/\/\([^\/]*\)$/-\\1/")[[:space:]]" | wc -l) -eq 1 ]
    then
      #
      # memo: ${#ptm_fs[n]} renvoi la longueur du 'n'ieme element du tableau 'ptm_fs'
      #
      # FQT
      # echo "${#ptm_fs[$i]}:/sys_alt${ptm_fs[$i]}:${part_clone[$i]}" >>${fic_table}
      echo "${#ptm_fs[$i]}:/sys_alt${ptm_fs[$i]}:${part_clone[$i]}:$i" >>${fic_table}
    fi
  fi
done

  if [ -s "${fic_table}" ]
  then
    sort -t":" -n -r ${fic_table} >${fic_table}.sort
    mv -f ${fic_table}.sort ${fic_table}

    message  -m SYSTEME_ALTERNE_I  "DEMONTAGE DES FS CLONES"

    if [ "${DEBUG}" = "1" ]
    then
      echo "---------------------------------------------------"
      echo "Contenu du fichier travail genere (${fic_table}) pour les FS clones a demonter :"
      echo "(longueur_point_montage_fs:nom_partition_clone)"
      cat ${fic_table}
      echo "---------------------------------------------------"
    fi

    # FQT
    # for part in $(cut -d":" -f2 ${fic_table})
    for lig in $(cat ${fic_table})
    do
      IFS_SAV="$IFS"
      IFS=":"
      set x $lig
      part=$3
      ind=$5
      IFS="${IFS_SAV}"
      # FQT fin

      message  -m SYSTEME_ALTERNE_I "Demontage de ${part}"

      umount ${part}
      if [ $? -ne 0 ]
      then
        message  -m SYSTEME_ALTERNE_E "Erreur lors du demontage de ${part}"
        FLAG_ERROR=1
      fi

      # FQT suppression de la partie du point 
      # de montage qui a due etre creee
      rep_perdu=${ptm_fs_perdu[$ind]}
      while [ "${rep_perdu}" ]; do
        rmdir ${ptm_fs_present[$ind]}${rep_perdu} >/dev/null 2>&1
        if [ $? -ne 0 ]; then
          message  -m SYSTEME_ALTERNE_E "Erreur rmdir ${ptm_fs_present[$ind]}${rep_perdu}"
          FLAG_ERROR=1
          break
        fi
        rep_perdu=$(echo ${rep_perdu} | sed 's/\/*[^\/]*[ \t]*$//')
      done
      # FQT fin
    done
  fi

  rm -f ${fic_table} 
  unset fic_table part mount_point
}

create_clone_mountpoint () {
# =========================================================================
message  -m SYSTEME_ALTERNE_I "MONTAGE DES FS CLONES ET RECOPIE DES DONNEES"
# =========================================================================
# ------------------------------------------------------------------------------
# Pour tous les FS a copier, et afin de les traiter du plus haut au plus bas
# dans l'arborescence,
# Constitution d'un fichier de travail temporaire avec les champs suivants :
# - longueur de la chaine de caracteres correspondante au point de montage du FS
# - point de montage du FS
# - nom de la partition clone
# Tri de ce fichier sur la longueur de la chaine (de la plus courte a la plus
# longue).
# Puis pour tous les FS presents dans ce fichier, FS apres FS, montage du FS
# clone et recopie des fichiers.
#
# ${RACINE_SYS_ALT} est utilise comme point de montage 'racine' du systeme
# alterne.
# ------------------------------------------------------------------------------

# Creation du repertoire 'racine' du systeme alterne, si necessaire 
# -----------------------------------------------------------------
[ ! -d ${RACINE_SYS_ALT} ] && mkdir ${RACINE_SYS_ALT}

# Constitution et tri du fichier temporaire
fic_table="/tmp/table_fs.$(basename ${disk_source}).$$"
>${fic_table}

typeset -i i
i=0
COUNTER=${nb_part}
while [ ${i} -lt $COUNTER ]
do
	i=$i+1
	if [ "${typ_part[$i]}" = "83" ]
	then
		#echo "
		if [ $(mount | sed "s#/dev/mapper/\([^-]*\)-\([^-]*\)#/dev/\1\/\2#" | egrep "^${part_src[$i]}[[:space:]]|^${part_src[$i]}[[:space:]]" | wc -l) -eq 1 ]
		then
			#
			# memo: ${#ptm_fs[n]} renvoi la longueur du 'n'ieme element du tableau 'ptm_fs'
			#
			# FQT
			echo "${#ptm_fs[$i]}:${ptm_fs[$i]}:${part_clone[$i]}:$i" >>${fic_table}
		else
			TEMP_I=${i}	
			message  -m SYSTEME_ALTERNE_I "Rappel: partition ${part_src[$i]} non montee, pas de recopie"
			i=${TEMP_I}
		fi
	fi
done

sort -t":" -n ${fic_table} >${fic_table}.sort
mv -f ${fic_table}.sort ${fic_table}

if [ "${DEBUG}" = "1" ]
then
	echo "---------------------------------------------------"
	echo "Contenu du fichier travail genere (${fic_table}) pour les FS a copier :"
	echo "(longueur_point_montage_fs:point_montage_fs:nom_partition_clone)"
	cat ${fic_table}
	echo "---------------------------------------------------"
fi

# Traitement des lignes du fichier temporaire
for lig in $(cat ${fic_table})
do
	lv_clone=$(echo $lig |cut -d":" -f3)
	mount_point=$(echo $lig |cut -d":" -f2)
	# FQT
	ind=$(echo $lig | cut -d ":" -f4)

	message  -m SYSTEME_ALTERNE_I "Recopie du filesystem ${mount_point}"

	# Montage de la partition clone ${lv_clone} sur ${RACINE_SYS_ALT}${mount_point}
	# ------------------------------------------------------------------------------
	[ "${DEBUG}" = "1" ] && echo "Montage de la partition ${lv_clone} sur ${RACINE_SYS_ALT}${mount_point}"
	# FQT
	# Controle de l'existance du point de montage
	ptm="$(controle_mount_point ${RACINE_SYS_ALT}$mount_point)"
	if [ $? -ne 0 ]; then
		demontage_fs_clone
		grub_sans_sys_alt
		terminer_ko
	fi

	set x $ptm
	ptm_fs_present[$ind]=$2
	ptm_fs_perdu[$ind]=$3

	# Creation de la partie du point de montage inexistante
	if [ "${ptm_fs_perdu[$ind]}" ]; then
		perm=`stat -c%a ${mount_point}`
		mkdir -p ${RACINE_SYS_ALT}${mount_point} > /dev/null 2>&1
		chmod $perm  ${RACINE_SYS_ALT}${mount_point}
		if [ $? -ne 0 ]; then
			message  -m SYSTEME_ALTERNE_E "Erreur creation repertoire ${RACINE_SYS_ALT}${mount_point}}"
			demontage_fs_clone
			grub_sans_sys_alt
			terminer_ko
		fi
	fi
	# FQT Fin

	mount ${lv_clone} ${RACINE_SYS_ALT}${mount_point}
	if [ $? -ne 0 ]
	then
		message  -m SYSTEME_ALTERNE_E "Erreur lors du montage de ${lv_clone} sur ${RACINE_SYS_ALT}${mount_point}"

		demontage_fs_clone
		grub_sans_sys_alt
		terminer_ko
	fi

	# Deplacement dans le point de montage du filesystem source
	# (car les noms de fichiers passes a la commande cpio doivent imperativement
	# etre en chemin relatif, c'est a dire commencer par un ".")
	# --------------------------------------------------------------------------
	[ "${DEBUG}" = "1" ] && echo "Deplacement dans ${mount_point}"

	copy_source_to_clone ${RACINE_SYS_ALT} ${mount_point}
	
done

rm -f ${fic_table}
unset fic_table cr lv_clone mount_point


# ========================================
# ======== Fin create_mountpoint =============
# ========================================
}


create_partition_table_clonedisk() {
# =========================================================================================
message  -m SYSTEME_ALTERNE_I "(RE-)CREATION DE LA TABLE DES PARTITIONS SUR LE DISQUE CLONE"
# =========================================================================================

# Recreation table de partition avec sfdisk (utilisation de l'option "-d")
# ------------------------------------------------------------------------
fic_table="/tmp/part_table.$(basename ${disk_source}).$$"

######
# Prise en charge de geometrie de disque differente
$SFDISK -d ${disk_source} >${fic_table}
CHS_PARAM=$(fdisk -l ${disk_source} | sed -r '3!d;s#([0-9]+)[^0-9]+([0-9]+)[^0-9]+([0-9]+).*#-H \1 -S \2 -C \3#')

if [ "${DEBUG}" = "1" ]
then
  $SFDISK --force ${CHS_PARAM} -L ${disk_clone} <${fic_table}
  cr=$?
else
  $SFDISK --force  ${CHS_PARAM} -L ${disk_clone} <${fic_table} >/dev/null 2>&1
  cr=$?
fi

fin=0

# Update du 20/02/2014
# Forces la MAJ de la table des partitions des disques
partprobe >/dev/null 2>&1
/usr/bin/rescan-scsi-bus.sh >/dev/null 2>&1


while [ $fin -eq 0 ]; do
   fin=1
   for part in $($SFDISK -l ${disk_clone}| grep -v "Empty$" | grep "^${disk_clone}" | cut -d" " -f1); do
      ls $part > /dev/null 2>&1
      if [ $? -ne 0 ]; then
         fin=0
      fi
   done
done

if [ ${cr} -ne 0 ]
then
  message  -m SYSTEME_ALTERNE_E "Erreur lors de la (re-)creation des partitions sur ${disk_clone}"
  message  -m SYSTEME_ALTERNE_E "Commande en echec: sfdisk ${disk_clone} <${fic_table}"

  ##grub_sans_sys_alt
  terminer_ko
fi


rm -f ${fic_table}
unset fic_table cr
# =========================================
# =========== Fin Main ====================
# =========================================

}


format_partition_clonedisk () {
# ========================================================================
message  -m SYSTEME_ALTERNE_I  "CREATION DES PARTITIONS SUR LE DISQUE CLONE"
# ========================================================================
# ------------------------------------------------------------------------------
# Seules les partitions de type '82' et '83' sont traitees dans cette procedure.
# (pour l'integration de LVM, il faudra prendre en compte les partitions de type
# 8E (Linux LVM)).
# ------------------------------------------------------------------------------

typeset -i nb_lv
nb_lv=0
typeset -i i
i=0
while [ ${i} -lt ${nb_part} ]
do
	i=$i+1
	#echo "i=$i ==== {typ_part[i]}=${typ_part[$i]} ==== nb_part=${nb_part}"
	case ${typ_part[$i]} in
		'8e' )
			#MODIF KSH93 de rhel6
			TEMP_I=${i}
			message  -m SYSTEME_ALTERNE_I "Creation d'un PV sur ${part_clone[$i]}"
			i=${TEMP_I}
			pvcreate "${part_clone[$i]}" >/dev/null 2>&1

			vg_src=$($PVS -o pv_name,vg_name "${part_src[$i]}" 2>/dev/null|$AWK -v PART_SRC="${part_src[$i]}" '$1~PART_SRC { print $2 }')
			# FQT
			vg_clone=$(nom_clone $vg_src)
			#MODIF KSH93 de rhel6
			TEMP_I=${i}
			message  -m SYSTEME_ALTERNE_I "Creation du vg alterne : ${vg_clone}"
			i=${TEMP_I}
			#MODIF vg_src_PEsize="`vgdisplay ${vg_src} | grep "PE Size" | awk '{print $3$4}'`"
			vg_src_PEsize=$($VGS -o vg_extent_size ${vg_src} 2>/dev/null|$AWK '{print $1}')
			# FQT
			sleep 4	
			$VGCREATE -s "${vg_src_PEsize}" "$vg_clone" "${part_clone[$i]}" >/dev/null

			#MODIF RHEL6 lv_src="`lvs ${vg_src} | tail -n +2 | awk '{print $1}'`"
			lv_src=$($LVS -o lv_name ${vg_src} 2>/dev/null|$AWK '{print $1}')

			for lv_act in ${lv_src}
			do
				# FQT
				lv_clone=$(nom_clone $lv_act)
				#MODIF KSH93 de rhel6
				TEMP_I=${i}
				message  -m SYSTEME_ALTERNE_I "Creation du lv alterne : /dev/${vg_clone}/${lv_clone}"
				i=${TEMP_I}
				# MODIF KSH93 lv_size="`lvdisplay /dev/${vg_src}/${lv_act} | grep "Current LE" | awk '{print $NF}'`"
				lv_size="$(lvdisplay /dev/${vg_src}/${lv_act} 2>/dev/null| awk '$0~/Current LE/ {print $NF}')"
					# FQT
				$LVCREATE -n ${lv_clone} -l ${lv_size} ${vg_clone} >/dev/null
				# MODIF KSH93 lv_fs_label="`tune2fs -l "/dev/${vg_src}/${lv_act}" 2>/dev/null | grep "Filesystem volume name" | awk '{print $NF}'`"
				lv_fs_label="$(tune2fs -l "/dev/${vg_src}/${lv_act}" 2>/dev/null | awk '$0~/Filesystem volume name:/ { print $NF }')"
				#MODIF KSH93 lv_fs_type="`grep "^/dev/mapper/${vg_src}-${lv_act}[[:space:]]" /etc/fstab | awk '{print $3}'`"
				lv_fs_type=$(grep "^/dev/mapper/${vg_src}-${lv_act}[[:space:]]" /etc/fstab | awk '{print $3}')
				#
				if [ "${lv_fs_type}" = "" ]
				then
					lv_fs_type="$(grep "^LABEL=${lv_fs_label}[[:space:]]" /etc/fstab | awk '{print $3}')"
				fi
				
				
				
			done
		;;
		'82' )
			# Creation espace de swap 
			# -----------------------
			# MODIF KSH93 pour rhel6
			TEMP_I=${i}
			message  -m SYSTEME_ALTERNE_I "Creation swap sur ${part_clone[$i]}"
			i=${TEMP_I}

			if [ "${DEBUG}" = "1" ]
			then
				echo "mkswap ${part_clone[$i]}"	
			fi
			mkswap -f ${part_clone[$i]} 2>&1 >/dev/null
			cr=$?
				
			if [ ${cr} -ne 0 ]
			then
				message  -m SYSTEME_ALTERNE_E "Erreur lors de la creation de la swap sur ${part_clone[$i]}"
				message  -m SYSTEME_ALTERNE_I "Commande en echec: mkswap ${part_clone[$i]}"

				grub_sans_sys_alt
				terminer_ko
			fi
		;;
		'83' )
			# Creation filesystem
			# -------------------

			# si le type de filesystem n'a pu etre determine sur la partition source,
			# alors pas de creation de filesystem sur la partition clone
			#
			if [ "${typ_fs[$i]}" = '' ]
			then
				# MODIF KSH93 pour rhel6
				TEMP_I=${i}
				message  -m SYSTEME_ALTERNE_I "Rappel: Le type de filesystem pour la partition ${part_src[$i]} de type ${typ_part[$i]}" 
				message  -m SYSTEME_ALTERNE_I  "n'a pas ete determine, pas de creation de filesystem sur la partition ${part_clone[$i]}"
				i=${TEMP_I}
			else
				#MODIF KSH93 de rhel6
				TEMP_I=${i}
				message  -m SYSTEME_ALTERNE_I "Creation filesystem en ${typ_fs[$i]} sur ${part_clone[$i]}"
				i=${TEMP_I}
				# si le type du fs est "ext3", alors commande : "mkfs.ext2 -j"
				# sinon commande : "mkfs.<type_du_fs>"
				#
				#echo "{part_src[$i]}=${part_src[$i]} ====== {part_clone[$i]}=${part_clone[$i]}"
				if [ "${typ_fs[$i]}" = 'ext3' ]
				then
					typ="ext2"
					options="-j"
				elif [ "${typ_fs[$i]}" = 'ext4' ]
				then
					typ='ext4'
					options=""
				else
					typ="${typ_fs[$i]}"
					options=""
				fi

				# si LABEL present sur la partition source, alors
				# le LABEL de la partition clone = "<label_partition_source>_alt"  
				#
				if [ -n "${label_part[$i]}" ]
				then
					# FQT
					#options="${options} -L ${label_part[$i]}_alt" 
					options="${options} -L $(nom_clone ${label_part[$i]})" 
				fi

				if [ "${DEBUG}" = "1" ]
				then
					echo "mkfs.${typ} ${options} ${part_clone[$i]}"
					mkfs.${typ} ${options} ${part_clone[$i]}
					cr=$?
				else
					# echo "mkfs.${typ} ${options} ${part_clone[$i]}"
					mkfs.${typ} ${options} ${part_clone[$i]} >/dev/null 2>&1
					cr=$?
				fi

				if [ ${cr} -ne 0 ]
				then
					message  -m SYSTEME_ALTERNE_E "Erreur lors de la creation du filesystem sur ${part_clone[$i]}"
					message  -m SYSTEME_ALTERNE_E "Commande en echec: mkfs.${typ} ${options} ${part_clone[$i]}"

					grub_sans_sys_alt
					terminer_ko
				fi
			fi
		;;
		'f'|' f' )
			# Le type de partition 'f' correspond a une partition etendue,
			# aucune action a mener
			#
		;;
		'0' )
			# Le type 0 est present sur les disques dos de moins de 4 partitions.
			# aucune action a mener
			#
		;;
		* )
			message  -m SYSTEME_ALTERNE_W "ATTENTION: la partition ${part_clone[$i]} de type ${typ_part[$i]} n'est pas traitee"
			FLAG_ERROR=1
		;;
	esac
done

unset typ options cr lv_clone vg_clone
#
# ====== Fin create_partition_clone_disk
# 
}


remove_lvm_device_clonedisk () {

######
# ajout LVM : Nettoyage du disk avant opération.
# TODO: vérif montage...
# MODIF RHEL6 VGNAME="`pvs | grep "^[[:space:]]*${disk_clone}" | awk '{print $2}'`"
VGNAME_clone=$($PVS -o pv_name,vg_name 2>/dev/null|$AWK -v DISK_CLONE=${disk_clone} '$1~DISK_CLONE { print $2 }')
PVNAME_clone=$($PVS -o pv_name,vg_name 2>/dev/null|$AWK -v DISK_CLONE=${disk_clone} '$1~DISK_CLONE { print $1 }')

if [ ! "${VGNAME_clone}" = "" ]
then
	$VGCHANGE -a n "${VGNAME_clone}" >/dev/null 2>&1
	for LVNAME in $($LVS "${VGNAME_clone}" 2>/dev/null| awk '{print $1}')
	do
		$LVREMOVE "/dev/${VGNAME_clone}/${LVNAME}" >/dev/null 2>&1
	done
	$VGREMOVE "${VGNAME_clone}" >/dev/null 2>&1
	$PVCHANGE -a n "${PVNAME_clone}" >/dev/null 2>&1
	$PVREMOVE "${PVNAME_clone}" >/dev/null 2>&1
	sleep 5
fi

}


recupere_infos_systeme_source () {
# ==============================================================================
message -m SYSTEME_ALTERNE_I "CONSTITUTION DES INFOS A PARTIR DU SYSTEME SOURCE"
# ==============================================================================

# nom des partitions sur le disque source
set -a part_src
# nom des partitions sur le disque clone
set -a part_clone
# type(id) des partitions
set -a typ_part
# label des partitions (pour les partitions de type '83')
set -a label_part
# type du filesystem (pour les partitions de type '83')
set -a typ_fs
# point de montage du filesystem (pour les partitions de type '83')
set -a ptm_fs
# FQT
# part du point de montage existant juste avant le montage du fs
set -a ptm_fs_present
# part du point de montage inexistant juste avant le montage du fs
# cas ou un fs a cloner est monte sur un fs non clone
set -a ptm_fs_perdu

#MODIF RHEL6
set -a dm_lv_src
set -a dm_lv_clone

# Nombre de partitions
# --------------------
nb_part=$($SFDISK -l ${disk_source} 2>/dev/null | grep "^${disk_source}" | wc -l)

# Constitution nom des partitions source
# --------------------------------------
i=0
for part in $($SFDISK -l ${disk_source} 2>/dev/null | grep "^${disk_source}" | cut -d" " -f1)
do
  i=$(expr $i + 1)
  part_src[$i]=$part
done

if [ "${DEBUG}" = "1" ]
then
  echo "---------------------------------------------------"
  i=0
  while [ ${i} -lt ${nb_part} ]
  do
    i=$(expr $i + 1)
    echo "partition source ${i} : ${part_src[$i]}"
  done
  echo "---------------------------------------------------"
fi


# Constitution nom des partitions clone
# -------------------------------------
i=0
for part in $($SFDISK -l ${disk_clone}  2>/dev/null | grep "^${disk_clone}" | cut -d" " -f1)
do
  i=$(expr $i + 1)
  part_clone[$i]=${part}
done

if [ "${DEBUG}" = "1" ]
then
  i=0
  while [ ${i} -lt ${nb_part} ]
  do
    i=$(expr $i + 1)
    echo "partition clone ${i} : ${part_clone[$i]}"
  done
  echo "---------------------------------------------------"
fi


# Constitution type des partitions
# --------------------------------
i=0
while [ ${i} -lt ${nb_part} ]
do
  i=$(expr $i + 1)
  typ_part[$i]=$($SFDISK --print-id ${disk_source} ${i})
done

if [ "${DEBUG}" = "1" ]
then
  i=0
  while [ ${i} -lt ${nb_part} ]
  do
    i=$(expr $i + 1)
    echo "type de la partition ${i} : ${typ_part[$i]}"
  done
  echo "---------------------------------------------------"
fi


# Constitution label des partitions (pour les partitions de type '83')
# --------------------------------------------------------------------
i=0
while [ ${i} -lt ${nb_part} ]
do
  i=$(expr $i + 1)
  if [ "${typ_part[$i]}" = "83" ]
  then
    label_part[$i]=$(e2label ${part_src[i]})
  else
    label_part[$i]=""
  fi
done

if [ "${DEBUG}" = "1" ]
then
  i=0
  while [ ${i} -lt ${nb_part} ]
  do
    i=$(expr $i + 1)
    echo "LABEL de la partition ${i} : ${label_part[$i]}"
  done
  echo "---------------------------------------------------"
fi

# Constitution des LV de FS si presence partition LVM (8e)
#
i=${nb_part}
vg_clone=$(nom_clone ${vgroot})
part_lvm=$(echo ${typ_part[*]}|grep -q '8e' ;echo $?)
if [ $part_lvm -eq 0 ]
then
	part_lvm=$($PVS -o pv_name 2>/dev/null|awk -v DISK_SOURCE="${disk_source}" '$1~DISK_SOURCE { print $1 }')
	for LV_NAME in $($LVS -o lv_name ${vgroot} 2>/dev/null|awk '{ print $1 }')
	do
		let i=${i}+1
		lv_src_name[$i]=${LV_NAME}
		lv_clone_name[$i]=$(nom_clone ${lv_src_name[$i]})
		part_src[$i]="/dev/${vgroot}/${lv_src_name[$i]}"
		part_clone[$i]="/dev/${vg_clone}/${lv_clone_name[$i]}"
		dm_lv_src[$i]="/dev/mapper/${vgroot}-${lv_src_name[$i]}"
		dm_lv_clone[$i]="/dev/mapper/${vg_clone}-${lv_clone_name[$i]}"
	

		#echo "informations : "
		#echo " ${lv_src_name[$i]}  ${lv_clone_name[$i]}  ${part_src[$i]}  ${part_clone[$i]}  ${dm_lv_src[$i]}  ${dm_lv_clone[$i]} "	
		typ_fs[$i]=$(awk -v var=${dm_lv_src[$i]} -v lv=${part_src[$i]} '$1==var || $1==lv { print $3 }' ${FIC_FSTAB})
		if [ ${typ_fs[$i]} = 'swap' ]; then
			typ_part[$i]=82
			LV_SWAP="${vgroot}/${lv_src_name[$i]}"
		else
			typ_part[$i]=83
		fi

	done

fi

nb_part=${i}

# Constitution type du filesystem et point de montage du filesystem
# (pour les partitions de type '83')
# -----------------------------------------------------------------
i=0
while [ ${i} -lt ${nb_part} ]
do
	let i=${i}+1
	# MODIF 
	#echo "{typ_part[$i]}=${typ_part[$i]} === part_src[$i]=${part_src[$i]} === dm_lv_src[$i]=${dm_lv_src[$i]}" # DEBUG 
	if [ "${typ_part[$i]}" = "83" ]
	then
		if [ $(mount | awk -v var=${part_src[$i]} -v lv_device=${dm_lv_src[$i]} '$1 == var || $1==lv_device  { print $0 }' | wc -l) -eq 1 ]
		then
			typ_fs[$i]=$(mount | awk -v var=${part_src[$i]} -v lv_device=${dm_lv_src[$i]} '$1 == var || $1==lv_device { print $5 }')
			ptm_fs[$i]=$(mount | awk -v var=${part_src[$i]} -v lv_device=${dm_lv_src[$i]} '$1 == var || $1==lv_device { print $3 }')

		else
			TEMP_I=${i}
			message  -m SYSTEME_ALTERNE_W "ATTENTION: partition ${part_src[$i]} de type ${typ_part[$i]} non montee"
			message  -m SYSTEME_ALTERNE_I "Recherche du type et du point de montage du filesystem dans ${FIC_FSTAB}"
			i=${TEMP_I}
			FLAG_ERROR=1

			# on recherche le type de FS dans /etc/fstab par le nom de la partition
			if [ $(awk -v var=${part_src[$i]} '{ if ( $1 == var ) print $0 }' ${FIC_FSTAB} | wc -l) -eq 1 ]
			then
				typ_fs[$i]=$(awk -v var=${part_src[$i]} '{ if ( $1 == var ) print $3 }' ${FIC_FSTAB})
				ptm_fs[$i]=$(awk -v var=${part_src[$i]} '{ if ( $1 == var ) print $2 }' ${FIC_FSTAB})
				#echo "I=$i   part_src[$i]=${part_src[$i]}  typ_fs[$i]=${typ_fs[$i]}   ptm_fs[$i]=${ptm_fs[$i]}"
			else
				# on recherche le type de FS dans /etc/fstab par le LABEL de la partition
				if [ $(awk -v var=${label_part[$i]} '{ if ( $1 == "LABEL="var ) print $0 }' ${FIC_FSTAB} | wc -l) -eq 1 ]
				then
					typ_fs[$i]=$(awk -v var=${label_part[$i]} '{ if ( $1 == "LABEL="var ) print $3 }' ${FIC_FSTAB})
					ptm_fs[$i]=$(awk -v var=${label_part[$i]} '{ if ( $1 == "LABEL="var ) print $2 }' ${FIC_FSTAB})
					#echo "I=$i   part_src[$i]=${part_src[$i]}  typ_fs[$i]=${typ_fs[$i]}   ptm_fs[$i]=${ptm_fs[$i]}"
				else
					TEMP_I=${i}
					message  -m SYSTEME_ALTERNE_W "Type et point de montage du FS indeterminable pour la partition ${part_src[$i]}"
					i=${TEMP_I}
					typ_fs[$i]=""
					ptm_fs[$i]=""
				fi
			fi
		fi
		if [ ${ptm_fs[$i]} = '/' ]; then
			LV_ROOT="${part_src[$i]}"
		fi
	else
		typ_fs[$i]=""
		ptm_fs[$i]=""
	fi
done

if [ "${DEBUG}" = "1" ]
then
  i=0
  while [ ${i} -lt ${nb_part} ]
  do
    i=$(expr $i + 1)
    echo "type FS pour la partition(id=83) ${i} : ${typ_fs[$i]}"
  done
  echo "---------------------------------------------------"
  i=0
  while [ ${i} -lt ${nb_part} ]
  do
    i=$(expr $i + 1)
    echo "point_de_montage du FS pour la partition(id=83) ${i} : ${ptm_fs[$i]}"
  done
  echo "---------------------------------------------------"
fi

# ==================================================
# ================ Fin recupere_infos_systeme_source =======
#====================================================
}



# Verification des pre-requis
check_prerequis() {
#
#
#
disk_clone=$1

# Verification existence du disk clone
$SFDISK -s ${disk_clone} >/dev/null
if [ $? -ne 0 ]
then
	message  -m SYSTEME_ALTERNE_E "Le disque ${disk_clone} n'existe pas"
	terminer_ko
fi

# Identification du disk source en recherchant ou est localise la partition "/"
device=$(df -P / | tail -1 | awk '{ print $1 }' | sed "s/\/dev\/mapper\/\([^-]*\)-\([^-]*\)$/\/dev\/\\1\\/\\2/")

# recherche du pv en cas de / sur lv
df -P / | tail -1 | awk '{ print $1 }' | grep "/dev/mapper" >/dev/null 2>&1
if [ $? -eq 0 ]
then
	vgroot=$(df -P / | tail -1 | awk '{ print $1 }' | sed "s/\/dev\/mapper\/\([^-]*\)-\([^-]*\)$/\\1/" )
	device=$($PVS 2>/dev/null| grep "[[:space:]]${vgroot}[[:space:]]" | awk '{ print $1 }')
fi

# verif si device de la partition "/" est de la forme 'c0d0p1' sinon de la forme 'sda1' ou 'hda1'
# Update du 20/02/2014 pour prise en charge du multipath du Boot on SAN
#echo ${device} | grep -e "c[[:digit:]]\+d[[:digit:]]\+p[[:digit:]]\+|mpath.*p[[:digit:]]\+$" -q
#echo ${device} | grep -E 'c[[:digit:]]\+d[[:digit:]]\+p[[:digit:]]\+|mpath.*p[[:digit:]]' -q
echo ${device} | grep -E 'c[[:digit:]]+d[[:digit:]]+p[[:digit:]]+|mpath.*p[[:digit:]]+' -q
if [ $? -eq 0 ]
then
	disk_source=$(echo ${device} | sed 's/p[[:digit:]]\+$//')
else
	disk_source=$(echo ${device} | sed 's/[[:digit:]]\+$//')
fi
unset device

# Verification disk clone n'est pas disk source
# ---------------------------------------------
if [ "${disk_clone}" = "${disk_source}" ]
then
	message   -m SYSTEME_ALTERNE_E "Le disque passe en argument correspond au disque source"
	terminer_ko
fi

# Verification 1 seul PV sur le disque source
# ---------------------------------------------
pvnum=$(pvs -o pv_name 2>/dev/null|awk -v DISK_SOURCE="/dev/sda" '$1~DISK_SOURCE { print $1 }' | wc -l )

if [ $pvnum -gt 1 ]
then
	 message   -m SYSTEME_ALTERNE_E  "$pvnum PV LVM  sur le disque source"
	 message   -m SYSTEME_ALTERNE_E  "le disque source n'est pas correct"
	terminer_ko
fi



# Verification existence fichiers
# -------------------------------
for file in "${FIC_DEVMAP}" "${FIC_CONFGRUB}" "${FIC_FSTAB}"
do
	if [ ! -s "${file}" ]
	then
		message  -m SYSTEME_ALTERNE_E "Fichier ${file} absent ou vide"
		terminer_ko
	fi
done

# Recherche du nom 'bios' utilise par GRUB du disk clone et du disk source
# ------------------------------------------------------------------------
bios_disk_clone=$(grep ${disk_clone} ${FIC_DEVMAP} | grep -v "^#" | awk '{ print $1 }'| sed 's/[()]//g')
if [ -z "${bios_disk_clone}" ]
then
	message  -m SYSTEME_ALTERNE_E "Nom 'bios' du Disque_Clone ${disk_clone} non trouve dans ${FIC_DEVMAP}"
	message  -m SYSTEME_ALTERNE_E "Ajouter le manuellement dans ${FIC_DEVMAP} si necessaire"
	terminer_ko
fi

bios_disk_source=$(grep ${disk_source} ${FIC_DEVMAP} | grep -v "^#" | awk '{ print $1 }'| sed 's/[()]//g')
if [ -z "${bios_disk_source}" ]
then
	message  -m SYSTEME_ALTERNE_E "Nom 'bios' du Disque_Source ${disk_source} non trouve dans ${FIC_DEVMAP}"
	message  -m SYSTEME_ALTERNE_E "Ajouter le manuellement dans ${FIC_DEVMAP} si necessaire"
	terminer_ko
fi

bios_disk_source=hd0
bios_disk_clone=hd1

message  -m SYSTEME_ALTERNE_I "Disque_Clone  : ${disk_clone} (nom 'bios' pour GRUB : ${bios_disk_clone})"
message  -m SYSTEME_ALTERNE_I "Disque_Source : ${disk_source} (nom 'bios' pour GRUB : ${bios_disk_source})"


#exit 0

# FQT verification a supprimer pour permettre le clonage du disque alterne vers le source.
# Utilisee pour savoir si c'est un clone du disque source ou du disque alterne.
# Clonage du disque source: CLONE_SOURCE=0 sinon CLONE_SOURCE=""
# Verification pas de "_alt" a la fin du LABEL des partitions type 83 sur le disk source
# car il pourrait s'agir deja d'un systeme alterne et dans ce cas sortie en erreur
# --------------------------------------------------------------------------------------
i=0
# FQT
CLONE_SOURCE=0
for part in $($SFDISK -l ${disk_source} 2>/dev/null| grep "^${disk_source}" | cut -d" " -f1)
do
	i=$(expr $i + 1)
	if [ "$($SFDISK --print-id ${disk_source} ${i})" = "83" ]
	then
		if [ $(e2label ${part} | grep "_alt$" | wc -l) -ne 0 ]
		then
			# FQT
			#message -m SYSTEME_ALTERNE_E "Presence de \"_alt\" a la fin du LABEL de la partition ${part}"
			#message -m SYSTEME_ALTERNE_E "il doit deja s'agir du systeme alterne"
			#terminer_ko
			CLONE_SOURCE=1
		fi
	fi
done

# Nouvelle methode de detection de sys alt
old_IFS=$IFS     # sauvegarde du séparateur de champ
IFS=$'\n'     # nouveau séparateur de champ, le caractère fin de ligne

mountfs=`mount`
for line in $(mount)
do
	lv=$(echo $line |awk '{print $1}')
	mont=$(echo $line |awk '{print $3}')

	if [ $mont == '/' ]; then

		if [ $(echo $lv | grep "_alt$" | wc -l) -ne 0 ]
		then
        	CLONE_SOURCE=1
        	break
		else
        	CLONE_SOURCE=0
		fi
	fi

done
IFS=$old_IFS




# Verification presence d'une partition contenant un FS "/boot" sur le disk source
# et que celle-ci est montee sinon sortie en erreur
# ************************************************************************************** 
# SI IL N'Y A PAS DE PARTITION "/boot" SUR VOTRE SYSTEME ("/boot" DEVANT ETRE DANS CE
# CAS UN REPERTOIRE SUR LA PARTITION "/" SUPPRIMER LE CONTROLE CI-DESSOUS)
# SI LA PARTITION "/boot" EST LOCALISEE SUR UN AUTRE DISQUE ALORS CE SCRIPT NE DOIT PAS
# ETRE UTILISE CAR LE SYSTEME ALTERNE GENERE SERA INCOMPLET
# ************************************************************************************** 
# --------------------------------------------------------------------------------------
flag_boot=0
for part in $($SFDISK -l ${disk_source} 2>/dev/null | grep "^${disk_source}" | cut -d" " -f1)
do
	if [ "$(df ${part} 2>/dev/null | grep ${part} | awk '{ print $NF }')" = "/boot" ]
	then
		flag_boot=1
	fi 
done

if [ ${flag_boot} -ne 1 ]
then
	message  -m SYSTEME_ALTERNE_E "Il faut une partition \"/\" et une partition \"/boot\" sur le disque source ${disk_source}"
	message  -m SYSTEME_ALTERNE_E "et qu'elles soient montees pour le bon fonctionnement de cette procedure"
	terminer_ko
fi

unset part flag_boot
}



update_clone_prompt () {
bashrc_clone="${RACINE_SYS_ALT}${FIC_BASHRC}"





old_IFS=$IFS     # sauvegarde du séparateur de champ  
IFS=$'\n'     # nouveau séparateur de champ, le caractère fin de ligne  

mountfs=`mount`
for line in $(mount)
do
	lv=$(echo $line |awk '{print $1}')
	mont=$(echo $line |awk '{print $3}')

	if [ $mont == '/' ]; then

		if [ $(echo $lv | grep "_alt$" | wc -l) -ne 0 ]
		then
        	CLONE_SOURCE=1
			break
		else
        	CLONE_SOURCE=0
	fi
fi

done
IFS=$old_IFS




if [ "$CLONE_SOURCE" -eq "1" ]; then
	# c est le CLONE
	sed 's/ PS1=\"(sys_alt)/ PS1=\"/' ${bashrc_clone} >${bashrc_clone}.tmp
else
	# c est pas le clone
	sed 's/ PS1=\"/ PS1=\"(sys_alt)/' ${bashrc_clone} >${bashrc_clone}.tmp
fi
mv -f ${bashrc_clone}.tmp ${bashrc_clone}
}


update_clone_prompt_orig () {
# ==============================================================================
message  -m SYSTEME_ALTERNE_I "MODIFICATION DU PROMPT PS1 SUR LE SYSTEME ALTERNE"
# ==============================================================================
# ----------------------------------------------------------------------------------------
# Normalement, "~<user>/.bash_profile" appelle "~<user>/.bashrc" qui appelle "/etc/bashrc"
# ----------------------------------------------------------------------------------------


# Definition nom complet du fichier "/etc/bashrc" sur le systeme alterne
# (il est donc localise sous ${RACINE_SYS_ALT})
# ----------------------------------------------------------------------
bashrc_clone="${RACINE_SYS_ALT}${FIC_BASHRC}"

message -m SYSTEME_ALTERNE_I "Nom complet du fichier modifie : ${bashrc_clone}"

if [ ! -s "${bashrc_clone}" ]
then
  message -m SYSTEME_ALTERNE_W "ATTENTION: Fichier ${bashrc_clone} absent ou vide"
  message -m SYSTEME_ALTERNE_W "Pas de mise a jour de PS1 sur le systeme alterne"
  FLAG_ERROR=1
else
  # cette procedure s'attend a trouver une seule fois, la definition de PS1 dans /etc/bashrc
  # comme c'est le cas lors d'une installation d'un serveur LINUX par souche EDFGDF.
  # (La chaine de caracteres recherchee est PS1=").
  # En cas d'evolution, il faudra adapter cette procedure.
  #
  # Si la chaine est trouvee, la procedure ajoute "(sys_alt)" au debut du prompt PS1
  #
  # MODIF KSH93
  if [ $(grep -v "^[[:space:]]*#" ${bashrc_clone} | grep "PS1=\"" | wc -l) -eq 1 ]
  then
    # FQT
    #if [ $(grep -v "^#" ${bashrc_clone} | grep "PS1=\"(sys_alt)" | wc -l) -eq 1 ]
    #then
    #  message -m SYSTEME_ALTERNE_W "Bizarre! la chaine de caracteres \"(sys_alt)\" est deja presente dans le prompt PS1"
    #  message -m SYSTEME_ALTERNE_W "Verifier la definition de PS1 sur le systeme source"
    #  FLAG_ERROR=1
    #else
    # MODIF KSH93	
	
        nb_occ=$(egrep -v "^[[:space:]]*#" ${bashrc_clone} | grep "PS1=\"(sys_alt)" | wc -l)
        #nb_occ=$(awk '$1!~/^#/ && $0!~/.*#.*PS1=\"/ && $0~/[[:space:]]PS1=\"/ ' ${bashrc_clone} |wc -l)
    if [[ "$CLONE_SOURCE" && $nb_occ -eq 0 ]] 
	#|| [[ ! "$CLONE_SOURCE" && $nb_occ -eq 1 ]]
    then
      message -m SYSTEME_ALTERNE_W "Verifier la definition de PS1 sur le systeme source"
      FLAG_ERROR=1
    else
      # FQT
      #sed 's/PS1=\"/PS1=\"(sys_alt)/' ${bashrc_clone} >${bashrc_clone}.tmp
      #cr1=$?
      if [ "$CLONE_SOURCE" ]
      then
                #sed 's/\(.*[^#].*&& PS1="\)\([.*$\)/\1#(sys_alt)\2' ${bashrc_clone} >${bashrc_clone}.tmp
        #sed 's/\sPS1=\"/\sPS1=\"(sys_alt)/' ${bashrc_clone} >${bashrc_clone}.tmp
                sed 's/ PS1=\"/ PS1=\"(sys_alt)/' ${bashrc_clone} >${bashrc_clone}.tmp
        cr1=$?
      else
        sed 's/ PS1=\"(sys_alt)/ PS1=\"/' ${bashrc_clone} >${bashrc_clone}.tmp
        cr1=$?
      fi

      if [ "${DEBUG}" = "1" ]
      then
        echo "---------------------------------------------------"
        echo "Contenu du fichier ${bashrc_clone} avant modification :"
        cat ${bashrc_clone}
      fi

      mv -f ${bashrc_clone}.tmp ${bashrc_clone}
      cr2=$?

      if [ "${DEBUG}" = "1" ]
      then
        echo "---------------------------------------------------"
        echo "Contenu du fichier ${bashrc_clone} apres modification :"
        cat ${bashrc_clone}
        echo "---------------------------------------------------"
      fi

      if [ ${cr1} -ne 0 -o ${cr2} -ne 0 ]
      then
        message -m SYSTEME_ALTERNE_E "Erreur lors de la modification de PS1 dans ${bashrc_clone}"
        FLAG_ERROR=1
      fi

    fi
  else
    message -m SYSTEME_ALTERNE_W "ATTENTION: la definition de PS1 n'a pas ete trouve (uniquement une fois)"
    message -m SYSTEME_ALTERNE_W "Pas de mise a jour de PS1 sur le systeme alterne"
    FLAG_ERROR=1
  fi
fi

# remise en place des droits sur le fichier, par precaution
# ---------------------------------------------------------
chmod 644 ${bashrc_clone}

unset bashrc_clone cr1 cr2

}

# Fonction terminer_ok
terminer_ok() {

  if [ ${FLAG_ERROR} = "1" ]
  then
    message -m SYSTEME_ALTERNE_I "*** FIN OK AVEC DES ERREURS"
        \rm /var/run/${PROG}.pid
    exit 1
  fi
  message -m SYSTEME_ALTERNE_I "*** FIN OK"
  \rm /var/run/${PROG}.pid
  exit 0
}

# Fonction terminer_ko
terminer_ko() {
        message -m SYSTEME_ALTERNE_E "*** FIN ECHEC"
        \rm /var/run/${PROG}.pid
        exit 2
}




#---------------
# # Initialisation des variables et environnement
#---------------
#set -x
PROG=$(basename $0)
# La variable LANG est imposee pour eviter toute fluctuation dans les resultats de commandes
export LANG=C
# Definition repertoires et enrichissement de FPATH
export SYSALTPATH='/outillage/PraSys/bin'
export DOMAINE="PraSys"
export R_ROOTDIR="/outillage"
export FPATH="${R_ROOTDIR}/lib:${R_ROOTDIR}/${DOMAINE}/lib"
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"
# Definition fichier catalogue des messages et fichier de log
export LIST_CATALOG="${R_ROOTDIR}/${DOMAINE}/messages/systeme_alterne.cat"
export MSGLOG="/var/${DOMAINE}/log/${PROG%%.*}.log"
# Chargement fichier d'environnement global
. /outillage/glob_par/config_systeme.env
####. config_systeme.env
# Flag pour le mode debug
DEBUG=0
# Flag pour indiquer en fin de procedure si des erreurs ont ete rencontre
FLAG_ERROR=0
# Point de montage 'racine' pour le systeme alterne
RACINE_SYS_ALT='/sys_alt'
# Fichier map des devices pour GRUB
FIC_DEVMAP='/boot/grub/device.map'
# Fichier de configuration GRUB
FIC_CONFGRUB='/boot/grub/grub.conf'
# Fichier "fstab" (table des FS)
FIC_FSTAB='/etc/fstab'
# Fichier "bashrc" (pour la modification du prompt PS1)
FIC_BASHRC='/etc/bashrc'
# Commandes utilisees avec les options
#PVS='/sbin/pvs --noheadings'
PVS='pvs --noheadings'
#VGS='/sbin/vgs --noheadings'
VGS='vgs --noheadings'
#LVS='/sbin/lvs --noheadings'
LVS='lvs --noheadings'
LVCREATE='lvcreate  --zero n '
VGCREATE='vgcreate'
PVREMOVE='pvremove -f '
VGREMOVE='vgremove -f '
LVREMOVE='lvremove -f '
VGCHANGE='vgchange'

#LVCREATE='/sbin/lvcreate'
#VGCREATE='/sbin/vgcreate'
#PVREMOVE='/sbin/pvremove -f '
#VGREMOVE='/sbin/vgremove -f '
#LVREMOVE='/sbin/lvremove -f '
SFDISK='/sbin/sfdisk'

typeset -i TEMP_I
typeset LV_ROOT
typeset LV_SWAP


# =======================CORPS PRINCIPAL DU SCRIPT=============================
#
# =============================================================================
message  -m SYSTEME_ALTERNE_I "*** DEBUT PROCEDURE"
# ===================================================================
message  -m SYSTEME_ALTERNE_I "PREPARATION ET VERIFICATIONS INITIALES"
# ===================================================================

# Verification execution par root
# -------------------------------
if [ $(whoami) != root ]
then
        message  -m SYSTEME_ALTERNE_E "Ce script doit être execute sous root."
        terminer_ko
fi

# Verification que le script n'est pas deja en cours d'execution
# -------------------------------
if [ -f /var/run/${PROG}.pid ]
then
    message  -m SYSTEME_ALTERNE_E "process en cours d'execution ou supprimier le fichier /var/run/${PROG}.pid"
    terminer_ko
else
        echo $$ >/var/run/${PROG}.pid
fi

# Verification mode debug
if [ "$1" = "-d" ]
then
        DEBUG=1
        shift
fi

# Verification syntaxe
if [ $# -ne 1 ]
then
        message  -m SYSTEME_ALTERNE_E "Syntaxe incorrecte (usage: $0 [-d] <nom_complet_du_fichier_device_du_disque_clone>)"
        terminer_ko
fi

FS_a_sauvegarder='/ /boot /home /tmp /var'



check_prerequis $1

recupere_infos_systeme_source
remove_lvm_device_clonedisk
create_partition_table_clonedisk
format_partition_clonedisk
create_clone_mountpoint
create_clone_fstab
update_clone_grub
update_clone_prompt
#install_grub_clonedisk
demontage_fs_clone
terminer_ok
#
# vim:ts=4:sw=4

## Changelog
# 2.0 ,summer 2014,  version initial
# 2.0.1, 21/11/2014  , mise a jour pour EL 6.6  (cause lvcreate: question sur signature swap )
# 2.0.2  27/11/2014  , mise a jour , (l 567 , un message d erreur est un message d info )

