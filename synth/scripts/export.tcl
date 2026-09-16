################################################################################
# Phivers PE - re-export the place and route hand-off from a finished run
#
# Reopens outputs/<run>/PhiversPE.db and writes the Innovus files again, without
# redoing synthesis. Useful when a deliverable failed, or when the hand-off has
# to be regenerated for a run that is already closed.
#
#   make export                  # scalar run
#   make export VECTOR=1         # vector run
################################################################################

source [file dirname [info script]]/setup.tcl
source $SCRIPTS_DIR/reports.tcl

set db $OUTPUTS_DIR/${TOP_MODULE}.db
if {![file isdirectory $db] && ![file exists $db]} {
    error "no database at $db - run 'make synth' for this configuration first"
}

banner "Reopening $db"
read_db $db

file mkdir $OUTPUTS_DIR/innovus
banner "Writing the Innovus hand-off"
write_design -base_name $OUTPUTS_DIR/innovus/${TOP_MODULE}

banner "Done - $OUTPUTS_DIR/innovus"
exit
