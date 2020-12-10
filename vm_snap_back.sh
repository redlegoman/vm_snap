#!/bin/bash
if [[ -z $1 ]]
then
		echo "usage"
		exit 1
fi

DAY=$(date +%a)
PATH=/usr/bin:$PATH
DIR=/data/VMBACKUPS
LOG=$DIR/vm_snap_back.$1.$DAY.log
exec > >(/usr/bin/tee -a $LOG)
exec 2>&1

for VMGUEST in $1
do
  echo "------------------------- $VMGUEST -----------------------"
	date
	
	DESTDIR=/data/VMBACKUPS/SNAPS/vmserver
	
	DOMAIN=$VMGUEST
	SNAPNAME="snap1"
	TEMP=/tmp/script.12
	CURRENTFILES=/tmp/snapshot_$DOMAIN_current.txt
	SNAPFILES=/tmp/snapshot_$DOMAIN_snap.txt
  echo "dumping xml"
	virsh dumpxml $DOMAIN > $DESTDIR/$DAY/$DOMAIN.$DAY.xml
	
	#record current files
  echo "record current files"
  virsh domblklist $DOMAIN --details|grep '[[:blank:]]*file'|grep -v cdrom > $CURRENTFILES
	STATUS=$? ; if [[ $STATUS -gt 0 ]] ; then echo "quitting" ; exit 1; fi
	
	#create snapshot
  echo "create snapshot"
	virsh snapshot-create-as $DOMAIN $SNAPNAME before_patching --atomic --disk-only
	STATUS=$? ; if [[ $STATUS -gt 0 ]] ; then echo "quitting" ; exit 1; fi
	
	#copy files away
  echo "copying files..."
	cat $CURRENTFILES | while read A B DISK FILE
	do
		date
		FILENAME=$(echo $FILE|awk -F"/" '{print $NF}')
		echo " - Copying $FILE $DESTDIR/$DAY/$FILENAME.$DAY ..."
    touch  $DESTDIR/$DAY
		cp $FILE $DESTDIR/$DAY/$FILENAME.$DAY
		STATUS=$? ; if [[ STATUS -ne 0 ]] ; then exit 10 ; fi
		date
	done
	
	echo
	
	# blockcommit 
  virsh domblklist $DOMAIN --details|grep '[[:blank:]]*file'|grep -v cdrom > $SNAPFILES
	STATUS=$? ; if [[ $STATUS -gt 0 ]] ; then echo "quitting" ; exit 1; fi
	
	cat $SNAPFILES|while read A B DISK FILE
	do
		echo " - committing $DISK ($FILE)"
		virsh blockcommit $DOMAIN $DISK --pivot --verbose
		STATUS=$? ; if [[ $STATUS -gt 0 ]] ; then echo "quitting" ; exit 1; fi
		echo " - deleting $FILE"
 		rm $FILE
		echo 	
	done
	echo
	
	#delete snapshot
	echo " - deleting snapshot $SNAPNAME "
	virsh snapshot-delete $DOMAIN $SNAPNAME --metadata
	STATUS=$? ; if [[ $STATUS -gt 0 ]] ; then echo "quitting" ; exit 1; fi
	date
	
done

echo " - "


