$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/lib"
=begin
  * Name: rkumar
  * $Id$
  * TODO
    * allow caller to pass ID and select and populate - was doing earlier but things have changed.
=end

require 'rubygems'
require 'ncurses'
require 'rbcurse/sqleditapplication'
require 'rbcurse/singletable'
require 'sqlite3'

include Ncurses
include Ncurses::Form

class ContractEdit1101  < Application

  ###DEFS_COME_HERE###
  def initialize()
    super()

    @helpfile = __FILE__
    @labelarr = nil
  end # initialize
  

  def run
    begin
    @db = SQLite3::Database.new('testd.db') 
    fields = nil
    #fields = SingleTable.generic_create_fields @db, "contracts" , 20

    #@eapp = SqlEditApplication.create_default_application(@db, "contracts", ["contract_id"], fields, {"mode"=>:view_one, "keys"=>["T200"]})  do
    SqlEditApplication.create_view_one_application(@db, "contracts", ["contract_id"], fields, ["T200"])  do
      #@rt_form={"classname"=>"NewContractEdit", "mydefs"=>"  def someproc\n\n  end\n", "myprocs"=>"  myfieldcheck = proc { |afield|\n    }\n"}
      #user_prefs(@rt_form)
     # form_headers["header_top_center"]='Contract Edit'
      form_headers["header_top_left"]='Demo' # << should be global
      #@sql_actions = [:delete, :update]  # example of restring user to only delete and update
      #@sql_actions = [:select, :findall]  # example of restraining user to only select abd findall
      #@sql_actions = [:select, :nosubmenu]    # nosubmenu means the ^X submenu wont be shown
      #set_sql_actions([:nosubmenu])    # nosubmenu means the ^X submenu wont be shown
      #
    end
    ensure
      @db.close if !@db.nil?
    end

  end # run

end # class

if __FILE__ == $0
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
    f = ContractEdit1101.new 
    f.run
  ensure
    Ncurses.endwin();
  end
end
