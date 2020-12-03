#
#                              --- version 3.1 ----
#                              - supports Jenkins -
#
#-------------------------------------------------------------------------------------------
# --- Libraries ----------------------------------------------- Edit for this Project ------
#-------------------------------------------------------------------------------------------

# library for programs  
BINLIB=WSCLIB

# library for data 
FILELIB=WSCFIL

# library for CNX
CNXLIB=VALENCE52P

# Other libraries you need for rpg compiles (in biblical order - the last will be first)
# Your BINLIB and FILELIB will be added to the end
LIBLIST = CMSFIL  

# other repositories your code might need - in the order you would expect
# Note: Utility is standard and should always be at the end
REPOLIST :=  Utility 



#-------------------------------------------------------------------------------------------
# --- Standard variable setup -------------------------------------- Do Not Change ---------
#-------------------------------------------------------------------------------------------


# shell to use (for consistency)
SHELL=/QOpenSys/usr/bin/qsh

# Compile option for easy debugging
DBGVIEW=*SOURCE

REPO_TEXT=$(BUILD_TAG)-$(GIT_BRANCH):$(BUILD_NUMBER)

#--------------------------------------------------------------------
# Make allowances for USRWRT on test and USRWRT400 on production

SYS := $(shell hostname)

ifeq ($(SYS), WTSBLADE.WRIGHTTREE.COM) 
   ifeq ($(BINLIB), USRWRT400)
      BINLIB=USRWRT
      FILELIB=USRFWRT
   endif
endif


#--------------------------------------------------------------------
# Fill variable BASELIBS - it will be used to add these to the library list
# Note: If your base libraries are not WSCFIL and WSCLIB, you will probably want to  
#       hard code them in your liblist below.
ifeq ($(FILELIB), $(BINLIB))
    BASELIBS:=$(FILELIB)
else
    BASELIBS:=$(FILELIB) $(BINLIB)
endif


#--------------------------------------------------------------------
# set the switch for searchpath

ifeq ($(GIT_BRANCH),origin/dev)
    STAGE=DEV
elseifeq ($(GIT_BRANCH),origin/test)
    STAGE=TEST
else 
    STAGE=MASTER
endif



#--------------------------------------------------------------------
# set the developer libraries if needed

# get your user name in all caps
USER_UPPER := $(shell echo $(USER) | tr a-z A-Z)

ifeq ($(strip $(GIT_BRANCH)),)

  # If your user name is in the path, we're assuming this is not 
  # going to build in the main libraries
  ifeq ($(USER_UPPER), $(findstring $(USER_UPPER),$(CURDIR)))
  # so override with the BINLIB and FILELIB in binlib.inc in your home directory
      include  ~/binlib.inc
	  
	  # re-set the switch for searchpath
      STAGE=DEVELOPER
	
  # and fill variable ADDLIBS with the overridden values to add these to the library list
     ifeq ($(FILELIB), $(BINLIB))
        ADDLIBS:=$(FILELIB)
     else
        ADDLIBS:=$(FILELIB) $(BINLIB)
     endif
  # and put the path in the text
  REPO_TEXT:= '$(shell pwd)'
  endif

endif

#--------------------------------------------------------------------
# add the override libraries to the library list
ifneq ($(strip $(OVRFILE)$(OVRBIN)),)
    ifneq ($(strip $(OVRFILE)),)
        FILELIB=$(OVRFILE)
    endif

    ifneq ($(strip $(OVRBIN)),)
        BINLIB=$(OVRBIN)
    endif
    ifeq ($(OVRFILE), $(OVRBIN))
        ADDLIBS:=$(OVRFILE)
     else
        ADDLIBS:=$(OVRFILE) $(OVRBIN)
     endif
endif
#--------------------------------------------------------------------

# Finalize the library list
LIBLIST += $(CNXLIB) $(BASELIBS) $(ADDLIBS)

#path for source
VPATH = source:header

#--------------------------------------------------------------------
# build the repository search path to be used in RPG compiles
SEARCHPATH = ''$(CURDIR)'' 

#WORKSPACE = /home/WSCOWNER/.jenkins/workspace/

# If we are working in our own library
ifeq ($(STAGE),DEVELOPMENT)
    SEARCHPATH += $(foreach repo,$(REPOLIST),  ''$(dir $(CURDIR))$(repo)'' ''$(WORKSPACE)$(repo)-test'' ''$(WORKSPACE)$(repo)-master'' ''/wright-service-corp/$(repo)'' )
	
#If we are working in Jenkins dev
else ifeq ($(STAGE),DEV)
        SEARCHPATH += $(foreach repo,$(REPOLIST), ''$(WORKSPACE)$(repo)-dev'', ''$(WORKSPACE)$(repo)-test'' ''$(WORKSPACE)$(repo)-master'' ''/wright-service-corp/$(repo)'' )
		
#If we are working in Jenkins test
else ifeq ($(STAGE),TEST)
        SEARCHPATH += $(foreach repo,$(REPOLIST), ''$(WORKSPACE)$(repo)-test'' ''$(WORKSPACE)$(repo)-master'' ''/wright-service-corp/$(repo)'' )
	
else
    #If we are working Jenkins master or wright-service-corp
        SEARCHPATH += $(foreach repo,$(REPOLIST), ''$(WORKSPACE)$(repo)-master'' ''/wright-service-corp/$(repo)'' )
endif
#--------------------------------------------------------------------




#-------------------------------------------------------------------------------------------
# --- Project Specific ---------------------------------------- Edit for this Project ------
#-------------------------------------------------------------------------------------------

# list of objects for your binding directory (format: pgmname_BNDDIRLIST)
testing_BNDDIRLIST = testing.entrymod logerrors.entrysrv
empclshst_BNDDIRLIST = empclshst.entrymod logerrors.entrysrv 
logerrors_BNDDIRLIST = logerrors.entrymod 




# everything you want to build here
all: logerrors.srvpgm 
#all: empoccchg.sqlobj uclxref.sqlobj return_employee_occupation_description.sqlobj empclshst.pgm unxrefcnx.cnxpgm


# dependency lists
empclshst.pgm: empclshst.bnddir empclshst.sqlrpgmod
logerrors.srvpgm: logerrors.bnddir logerrors.sqlrpgmod logerrors.bndsrc
logerrors.rpgmod: logerrors.sqlrpgle
 
 





#-------------------------------------------------------------------------------------------
# --- Standard Build Rules ------------------------------------- Do Not Change -------------
#-------------------------------------------------------------------------------------------


%.bnddir:
	-system -q "CRTBNDDIR BNDDIR($(BINLIB)/$*)"
	@touch $*.bnddir


# sql statements should build in the data library
%.sqlobj: %.sql
	sed 's/FILELIB/$(FILELIB)/g' ./source/$*.sql  > ./source/$*.sql2
	liblist -a $(LIBLIST);\
	system "ADDRPYLE SEQNBR(1500) MSGID(CPA32B2) RPY('I')";\
	system "CHGJOB INQMSGRPY(*SYSRPYL)";\
	system "RUNSQLSTM SRCSTMF('./source/$*.sql2')";
	@touch $@
	system "RMVRPYLE SEQNBR(1500)";
	rm ./source/$*.sql2


%.sqlrpgmod: %.sqlrpgle
	liblist -a $(LIBLIST);\
	system "CRTSQLRPGI OBJ($(BINLIB)/$*) SRCSTMF('./source/$*.sqlrpgle') \
	COMMIT(*NONE) OBJTYPE(*MODULE) OPTION(*EVENTF) REPLACE(*YES) DBGVIEW($(DBGVIEW)) \
	TEXT($(REPO_TEXT)) \
	compileopt('INCDIR($(SEARCHPATH))')" 
	@touch $@


%.sqlrpgpgm:
	liblist -a $(LIBLIST);\
	system "CRTSQLRPGI OBJ($(BINLIB)/$*) SRCSTMF('./source/$*.sqlrpgle') \
	COMMIT(*NONE) OBJTYPE(*PGM) OPTION(*EVENTF) REPLACE(*YES) DBGVIEW($(DBGVIEW)) \
	TEXT($(REPO_TEXT)) \
	compileopt('INCDIR( $(SEARCHPATH))')"; 
	@touch $@


%.lvl2mod: %.sqlrpgle
	liblist -a $(LIBLIST);\
	system "CRTSQLRPGI OBJ($(BINLIB)/$*) SRCSTMF('./source/$*.sqlrpgle') \
	COMMIT(*NONE) OBJTYPE(*MODULE) OPTION(*EVENTF) REPLACE(*YES) DBGVIEW($(DBGVIEW)) \
	RPGPPOPT(*LVL2) \
	TEXT($(REPO_TEXT)) \
	compileopt('INCDIR( $(SEARCHPATH))')";
	@touch $@


%.lvl2pgm:
	liblist -a $(LIBLIST);\
	system "CRTSQLRPGI OBJ($(BINLIB)/$*) SRCSTMF('./source/$*.sqlrpgle') \
	COMMIT(*NONE) OBJTYPE(*PGM) OPTION(*EVENTF) REPLACE(*YES) DBGVIEW($(DBGVIEW)) \
	RPGPPOPT(*LVL2) \
	TEXT($(REPO_TEXT)) \
	compileopt('INCDIR( $(SEARCHPATH))')";
	@touch $@


%.rpglemod: %.rpgle
	liblist -a $(LIBLIST);\
	system "CRTRPGMOD MODULE($(BINLIB)/$*) SRCSTMF('./source/$*.rpgle') DBGVIEW($(DBGVIEW)) REPLACE(*YES)" 
	@touch $@


%.rpglepgm: %.rpgle
	liblist -a $(LIBLIST);\
	system "CRTBNDRPG PGM($(BINLIB)/$*) SRCSTMF('./source/$*.rpgle') \
	OPTION(*EVENTF) DBGVIEW(*SOURCE) REPLACE(*YES) \
	INCDIR($(subst '',',$(SEARCHPATH)))";
	@touch $@


%.pgm:
	-system -q "ADDBNDDIRE BNDDIR($(BINLIB)/$*) OBJ($(patsubst %.entrysrv,(*LIBL/% *SRVPGM *IMMED), $(patsubst %.entrymod,(*LIBL/% *MODULE *IMMED),$($*_BNDDIRLIST))))";
	liblist -a $(LIBLIST);\
	system "CRTPGM PGM($(BINLIB)/$*)  BNDDIR($(BINLIB)/$*) REPLACE(*YES)"
	@touch $@


%.cllebndpgm:  %.clle
	-system -q "CRTSRCPF FILE($(BINLIB)/QCLLESRC) RCDLEN(92)"
	system "CPYFRMSTMF FROMSTMF('./source/$*.clle') TOMBR('/QSYS.lib/$(BINLIB).lib/QCLLESRC.file/$*.mbr') MBROPT(*replace)"
	system "CHGPFM FILE($(BINLIB)/QCLLESRC) MBR($*) SRCTYPE(CLLE)"
	liblist -a $(LIBLIST);\
	system "CRTBNDCL PGM($(BINLIB)/$*) SRCFILE($(BINLIB)/QCLLESRC)"
	@touch $@


%.cllemod: %.clle
	-system -q "CRTSRCPF FILE($(BINLIB)/QCLLESRC) RCDLEN(92)"
	system "CPYFRMSTMF FROMSTMF('./source/$*.clle') TOMBR('/QSYS.lib/$(BINLIB).lib/QCLLESRC.file/$*.mbr') MBROPT(*replace)"
	system "CHGPFM FILE($(BINLIB)/QCLLESRC) MBR($*) SRCTYPE(CLLE)"
	liblist -a $(LIBLIST);\
	system "CRTCLMOD MODULE($(BINLIB)/$*) SRCFILE($(BINLIB)/QCLLESRC) SRCMBR($*) OPTION(*EVENTF) REPLACE(*YES) DBGVIEW(*SOURCE)"
	@touch $@


%.prtfile: %.prtf
	-system -q "CRTSRCPF FILE($(BINLIB)/QDDSSRC) RCDLEN(112)"
	system "CPYFRMSTMF FROMSTMF('./source/$*.prtf') TOMBR('/QSYS.lib/$(BINLIB).lib/QDDSSRC.file/$*.mbr') MBROPT(*replace)"
	system "CHGPFM FILE($(BINLIB)/QCLLESRC) MBR($*) SRCTYPE(PRTF)"
	system "CRTPRTF FILE($(BINLIB)/$*) SRCFILE($(BINLIB)/QDDSSRC) SRCMBR($*) TEXT($(REPO_TEXT))"
	@touch $@


%.srvpgm:
    # We need the binder source as a member! Also requires a bindir SRCSTMF on CRTSRVPGM not available on all releases.
	-system -q "CRTSRCPF FILE($(BINLIB)/QSRC) RCDLEN(112)"
	system "CPYFRMSTMF FROMSTMF('./header/$*.bndsrc') TOMBR('/QSYS.lib/$(BINLIB).lib/QSRC.file/$*.mbr') MBROPT(*replace)"
	system "CHGPFM FILE($(BINLIB)/QSRC) MBR($*) SRCTYPE(BND)"
	-system -q "ADDBNDDIRE BNDDIR($(BINLIB)/$*) OBJ($(patsubst %.entrysrv,(*LIBL/% *SRVPGM *IMMED), $(patsubst %.entrymod,(*LIBL/% *MODULE *IMMED),$($*_BNDDIRLIST))))";\
	liblist -a $(LIBLIST);\
	system "CRTSRVPGM SRVPGM($(BINLIB)/$*) BNDDIR($(BINLIB)/$*) SRCFILE($(BINLIB)/QSRC)"
	@touch $@


%.pffile: %.pf
	-system -q "CRTSRCPF FILE($(BINLIB)/QDDSSRC) RCDLEN(112)"
	system "CPYFRMSTMF FROMSTMF('./source/$*.pf') TOMBR('/QSYS.lib/$(BINLIB).lib/QDDSSRC.file/$*.mbr') MBROPT(*replace)"
	system "CHGPFM FILE($(BINLIB)/QDDSSRC) MBR($*) SRCTYPE(PF)"
	liblist -a $(LIBLIST);\
	system "CRTPF FILE($(BINLIB)/$*) SRCFILE($(BINLIB)/QDDSSRC) SRCMBR($*) LVLCHK(*NO) TEXT($(REPO_TEXT))"
	@touch $@


%.lgcfile: %.lf
	-system -q "CRTSRCPF FILE($(BINLIB)/QDDSSRC) RCDLEN(112)"
	system "CPYFRMSTMF FROMSTMF('./source/$*.lf') TOMBR('/QSYS.lib/$(BINLIB).lib/QDDSSRC.file/$*.mbr') MBROPT(*replace)"
	system "CHGPFM FILE($(BINLIB)/QDDSSRC) MBR($*) SRCTYPE(LF)"
	liblist -a $(LIBLIST);\
	system "CRTLF FILE($(BINLIB)/$*) SRCFILE($(BINLIB)/QDDSSRC) SRCMBR($*) LVLCHK(*NO) TEXT($(REPO_TEXT))"
	@touch $@


%.entry:
    # Basically do nothing..
	@echo ""
	
%.entrymod:
    # Basically do nothing..
	@echo ""
	
%.entrysrv:
    # Basically do nothing..
	@echo ""
	
%.sqlrpgle:
    # Basically do nothing..
	@echo ""
