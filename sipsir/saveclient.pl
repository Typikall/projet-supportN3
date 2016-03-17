#!/usr/bin/perl

unshift(@INC,"./","/data/sipsir/outillage");
use Getopt::Std;
use Getopt::Long;
Getopt::Long::Configure("pass_through");
use Switch;

my ($help, $mac, $ip, $netmask,$gateway,$profil);
sub usage
{
        print "Unknown option: @_\n" if ( @_ );
        print "usage: $0 [--type TYPE_SAVE (p/m/q)] [--hostname HOSTNAME] [-i ip] [-W Utilisateur] [--help|-?]\n";
        exit;
}
$arguments=join(' ', @ARGV);
usage() if ( @ARGV < 1 or
! GetOptions('help|?' => \$help, 'n|hostname=s' => \$hostname, 't|type=s' => \$type, 'W|user=s' => \$user, 'i|ip=s' =>\$ip)
or defined $help );

if(!$hostname || !$user || !$type) {
        usage();
        exit 3;
}

require "fonctions.pl";
ecrirelog("HOSTNAMESIP = ${nomsip}");
ecrirelog("HOSTNAMECLIENT = ${hostname}");
ecrirelog("DATE_DEB = ${datelog}");
ecrirelog("SYNC = N");
ecrirelog("LOG_ASYNC = ${logfileasync}");
ecrirelog("ARGS = ${arguments}");
shortHost($hostname);
getGroupe($user);
chomp($groupe);
$type =~ tr /A-Z/a-z/ ;
if(!verifGroupe($groupe)) {
        ecrirelog("MSG_RET = Le Groupe n'existe pas");
        ecrirelog("ARGS_RET = Erreur");
        $datefin=`date +%Y%m%d_%H%M%S`;
        chomp($datefin);
        ecrirelog("DATE_FIN = ${datefin}");
        ecrirelog("STATUS = 184");
        exit 4;
}
if(!verifSave($type)) {
        ecrirelog("MSG_RET = Type de sauvegarde incorrect");
        ecrirelog("ARGS_RET = Erreur");
        $datefin=`date +%Y%m%d_%H%M%S`;
        chomp($datefin);
        ecrirelog("DATE_FIN = ${datefin}");
        ecrirelog("STATUS = 184");
        exit 4;
}

# Le test doit se faire sur le nom long car 6 suffixes DNS max dans le reseolv.conf
#$test=`func $shortname ping`;
$test=`func $hostname ping`;
if($test !~ /\[ ok ... \]/) {
        ecrirelog("MSG_RET = Client non joignable");
        ecrirelog("ARGS_RET = Client non joignable");
        $datefin=`date +%Y%m%d_%H%M%S`;
        chomp($datefin);
        ecrirelog("DATE_FIN = ${datefin}");
        ecrirelog("STATUS = 10");
        exit 10;
}

if($type eq 'q') {
        $pra="pra";
} else {
        if($type eq 'm') {
                $pra="nonpra/mens";
        } else {
                $pra="nonpra/ponct";
        }
}
$Sauvegarde=$cheminSauve."/".$groupe."/".$pra."/".$hostname."/";

if(!verifDeclar($shortname)){
        ecrirelog("MSG_RET = La machine n'est pas declaree");
        ecrirelog("ARGS_RET = Erreur");
        $datefin=`date +%Y%m%d_%H%M%S`;
        chomp($datefin);
        ecrirelog("DATE_FIN = ${datefin}");
        ecrirelog("STATUS = 184");
        exit 4;
}
if (!-d $Sauvegarde) {
        $creationrep=`mkdir -p ${Sauvegarde}`;
}
$tailledispo=`df -m $Sauvegarde | tail -n1 | awk '{print \$3}'`;

if ( $tailledispo < 1000 ) {
        ecrirelog("MSG_RET = Il y a moins d'1 Go disponible sur le SIP dans le repertoire ${Sauvegarde}");
        ecrirelog("ARGS_RET = Erreur");
        $datefin=`date +%Y%m%d_%H%M%S`;
        chomp($datefin);
        ecrirelog("DATE_FIN = ${datefin}");
        ecrirelog("STATUS = 1");
        exit 1;
}
addNFS($Sauvegarde,$hostname);
if ($adderror == 1 ) {
        ecrirelog("MSG_RET = Sauvegarde deja en cours");
        ecrirelog("ARGS_RET = Erreur");
        $datefin=`date +%Y%m%d_%H%M%S`;
        chomp($datefin);
        ecrirelog("DATE_FIN = ${datefin}");
        ecrirelog("STATUS = 1");
        exit 1;
}

my $cmd_save;
my $cmd_save_partition;

my @stdout = qx{func $hostname call system list_modules};
my $lines = join(" ",@stdout);
#my $pre_cmd_save = 'func ' . $hostname . ' call command run "if [ -x /etc/rear/exclude_fs.sh ];then /etc/rear/exclude_fs.sh; fi"';
if ($lines =~ /saveclient/ ) {
        # Cas des client en SIPSIR-CLIENT => 3.1
        $cmd_save = "func " . $hostname . " call --async saveclient saveclient";
        $cmd_save_partition = "/usr/bin/func " . $hostname . " call --async saveclient saveclient_partition";
} else {
        # Cas des client en SIPSIR-CLIENT <= 3.0 ou Calibre
        my ($stout, $sterr, $stexit) = `func $hostname call command run "facter -p lsbdistid"`;
        if ($stout =~ /RedHat/) {
                # Uniquement pour les RedHat
                # On desactive puppet comme en 3.1.1
                $commande=`/sbin/service puppet stop >/dev/null ;/sbin/chkconfig puppet off >/dev/null`;
                # On copie les anciens correctifs et la conf pour rear 1.12
                $cmd_old_rear_part = "func " . $hostname . ' call command run "/usr/bin/wget -q -O /usr/share/rear/layout/save/GNU/Linux/20_partition_layout.sh http://SIP/produits/produits_bundlesysEDF/svr_sipsir-client/rear_1.12/20_partition_layout.sh ;chmod 644 /usr/share/rear/layout/save/GNU/Linux/20_partition_layout.sh"';
                $cmd_old_rear_conf = "func " . $hostname . ' call command run "/usr/bin/wget -q -O /usr/share/rear/conf/default.conf http://SIP/produits/produits_bundlesysEDF/svr_sipsir-client/rear_1.12/default.conf ;chmod 644 /usr/share/rear/conf/default.conf"';
                $commande=`$cmd_old_rear_part`;
                $commande=`$cmd_old_rear_conf`;
        }
        $cmd_save = "func " . $hostname . ' call command run "echo NETFS_URL="nfs4://SIP/" > /tmp/confsave && PATH="/usr/local/bin:/bin:/usr/bin:/sbin" /usr/sbin/rear mkbackup"';
        $cmd_save_partition = "func ". $hostname . ' call command run "if [ -x /etc/rear/copy_to_SIP.sh ]; then bash /etc/rear/copy_to_SIP.sh ; else mount -t nfs4 SIP:/ /mnt/cdrom && rm -Rf /mnt/cdrom/recovery && rm -Rf /mnt/cdrom/layout && cp -Rf /var/lib/rear/* /mnt/cdrom && cp -Rp /etc/rear /mnt/cdrom/etc_rear && umount /mnt/cdrom ;fi"';
}

$parent = $$;
defined (my $pid = fork) or die "fork: $!";
if ($pid==0) {
        close (STDIN);
        close (STDOUT);
        close (STDERR);
        #my($stdout, $stderr, $exit) = `func "$hostname" call saveclient saveclient`;
        my($stdout, $stderr, $exit) = `$pre_cmd_save`;
        my($stdout, $stderr, $exit) = `$cmd_save`;
        @retourfunc=split(',',$stdout);
        if(@retourfunc['1'] =~ /\[0/) {
                #$test=`func "$hostname" call saveclient saveclient_partition`;
                my($stout, $sterr, $stexit) = `$cmd_save_partition`;
                ecrirelogasync("HOSTNAMESIP = ${nomsip}");
                ecrirelogasync("HOSTNAMECLIENT = ${hostname}");
                ecrirelogasync("DATE_DEB = ${datelog}");
                ecrirelogasync("SYNC = N");
                ecrirelogasync("LOG_ASYNC = ${logfileasync}");
                ecrirelogasync("ARGS = ${arguments}");
                $datefin=`date +%Y%m%d_%H%M%S`;
                chomp($datefin);
                my $backup_files = $Sauvegarde . "*backup_*.tar.gz ";
                $nomsave=`ls -1 $backup_files | tail -n 1`;
                chomp($nomsave);
                $taillesave = `ls -l $backup_files | awk 'END \{print \$5\}'`;
                chomp($taillesave);
                $typemaj=uc $type;
                $dsave=$nomsave;
                $dsave=~ s/.*backup_//g;
                $dsave=~ s/.tar.gz//g;
                #On teste que le fichier d'archive est plus recent que la date de creation du log du saveclient
                #Si plus recent on genere le log de sauvegarde OK sinon on sort en erreur en precisant que l'archive est manquante
                system("echo $nomsave  ${datelog} $dsave   > /tmp/DEBUG");
                if (( -f $nomsave ) && ( $datelog lt $dsave)){
                        ecrirelogasync("MSG_RET = Sauvegarde OK");
                        ecrirelogasync("ARGS_RET = ${typemaj} : ${nomsave} : ${taillesave}");
                        ecrirelogasync("DATE_FIN = ${datefin}");
                        ecrirelogasync("STATUS = 0");
                }
                else
                {
                        ecrirelogasync("MSG_RET = Sauvegarde NOK");
                        ecrirelogasync("ARGS_RET = Aucun fichier de sauvegarde");
                        ecrirelogasync("DATE_FIN = ${datefin}");
                        ecrirelogasync("STATUS = 193");
                }

        } else {
                ecrirelogasync("HOSTNAMESIP = ${nomsip}");
                ecrirelogasync("HOSTNAMECLIENT = ${hostname}");
                ecrirelogasync("DATE_DEB = ${datelog}");
                ecrirelogasync("SYNC = N");
                ecrirelogasync("LOG_ASYNC = ${logfileasync}");
                ecrirelogasync("ARGS = ${arguments}");
                $datefin=`date +%Y%m%d_%H%M%S`;
                chomp($datefin);
                chomp($stderr);
                $typemaj=uc $type;
                my $backup_files = $Sauvegarde . "*backup_*.tar.gz ";
                $nomsave=`ls -1 $backup_files | tail -n 1`;
                chomp($nomsave);
                print "$nomsave \n";
                $dsave=$nomsave;
                $dsave=~ s/.*backup_//g;
                $dsave=~ s/.tar.gz//g;
                # On teste la presence du fichier de sauvegarde, si present on le supprime puis on le signale dans MSG_RET
                system("echo $nomsave  ${datelog} $dsave   > /tmp/DEBUG");
                if (( -f $nomsave ) && ( $datelog lt $dsave))
                {
                       unlink $nomsave ;
                }
                ecrirelogasync("MSG_RET = Sauvegarde NOK");
                ecrirelogasync("MSG_RET = Suppression du fichier de sauvegarde");
                ecrirelogasync("ARGS_RET = $sterr $stderr $stdout $stout");
                ecrirelogasync("DATE_FIN = ${datefin}");
                ecrirelogasync("STATUS = 193");
        }
        delNFS($hostname);
        system("cp $logfileasync $logasynch");
        exit 0;
} else {
        ecrirelog("MSG_RET = Declenchement sauvegarde OK");
        ecrirelog("ARGS_RET = OK");
        $datefin=`date +%Y%m%d_%H%M%S`;
        chomp($datefin);
        ecrirelog("DATE_FIN = ${datefin}");
        ecrirelog("STATUS = 0");
        close (STDIN);
        close (STDOUT);
        close (STDERR);
        exit 0;
}
exit 0;

