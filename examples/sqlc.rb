## rahul kumar, 2009
# to demonstrate usage of rbcurse
# Use C-q to quit
#
require 'rubygems'
require 'ncurses'
require 'logger'
require 'sqlite3'
require 'rbcurse'
require 'rbcurse/rcombo'
require 'rbcurse/rtextarea'
require 'rbcurse/rtable'
#require 'rbcurse/table/tablecellrenderer'
require 'rbcurse/comboboxcellrenderer'
require 'rbcurse/keylabelprinter'
require 'rbcurse/applicationheader'
require 'rbcurse/action'

# pls get testd.db from
# http://www.benegal.org/files/screen/testd.db
# or put some other sqlite3 db name there.

## must give me @content, @columns, @datatypes (opt)
class Datasource
# attr_reader :field_length         # specified by user, length of row in display table
  attr_accessor :columns      # names of columns in array
  attr_accessor :datatypes    # array of datatyps of columns required to align: int, real, float, smallint
  attr_accessor :content    # 2 dim data
  attr_accessor :user_columns  # columnnames provided by user, overrides what is generated for display
# attr_reader :sqlstring           # specified by user

  # constructor
  def initialize(config={}, &block)
    @content = []
    @columns = nil # actual db columnnames -- needed to figure out datatypes
    @user_columns = nil # user specified db columnnames, overrides what may be provided
    @datatypes = nil
#   @rows = nil
#   @sqlstring = nil
#   @command = nil

    instance_eval(&block) if block_given?
  end
  def connect dbname
   @db = SQLite3::Database.new(dbname)
  end
  # get columns and datatypes, prefetch
  def get_data command
    @columns, *rows = @db.execute2(command)
    @content = rows
    return nil if @content.nil? or @content[0].nil?
    @datatypes = @content[0].types #if @datatypes.nil?
    @command = command
    return @content
  end
  def get_metadata table
    get_data "select * from #{table} limit 1"
    return @columns
  end
  ##
  # returns columns_widths, and updates that variable
  def estimate_column_widths tablewidth, columns
    colwidths = {}
    min_column_width = (tablewidth/columns.length) -1
    $log.debug("min: #{min_column_width}, #{tablewidth}")
    @content.each_with_index do |row, cix|
      break if cix >= 20
      row.each_index do |ix|
        col = row[ix]
        colwidths[ix] ||= 0
        colwidths[ix] = [colwidths[ix], col.length].max
      end
    end
    total = 0
    colwidths.each_pair do |k,v|
      name = columns[k.to_i]
      colwidths[name] = v
      total += v
    end
    colwidths["__TOTAL__"] = total
    column_widths = colwidths
    @max_data_widths = column_widths.dup

    columns.each_with_index do | col, i|
        if @datatypes[i].match(/(real|int)/) != nil
          wid = column_widths[i]
       #   cw = [column_widths[i], [8,min_column_width].min].max
          $log.debug("XXX #{wid}. #{columns[i].length}")
          cw = [wid, columns[i].length].max
          $log.debug("int #{col} #{column_widths[i]}, #{cw}")
        elsif @datatypes[i].match(/(date)/) != nil
          cw = [column_widths[i], [12,min_column_width].min].max
          #cw = [12,min_column_width].min
          $log.debug("date #{col}  #{column_widths[i]}, #{cw}")
        else
          cw = [column_widths[i], min_column_width].max
          if column_widths[i] <= col.length and col.length <= min_column_width
            cw = col.length
          end
          $log.debug("else #{col} #{column_widths[i]}, #{col.length} #{cw}")
        end
        column_widths[i] = cw
        total += cw
    end
    column_widths["__TOTAL__"] = total
    $log.debug("Estimated col widths: #{column_widths.inspect}")
    @column_widths = column_widths
    return column_widths
  end

  # added to enable query form to allow movement into table only if
  # there is data 2008-10-08 17:46 
  # returns number of rows fetched
  def data_length
    return @content.length 
  end
 
end
def get_key_labels
  key_labels = [
    ['C-q', 'Exit'], nil,
    ['M-s', 'Save'], ['M-m', 'Move']
  ]
  return key_labels
end
def get_key_labels_table
  key_labels = [
    ['M-n','NewRow'], ['M-d','DelRow'],
    ['C-x','Select'], nil,
    ['M-0', 'Top'], ['M-9', 'End'],
    ['C-p', 'PgUp'], ['C-n', 'PgDn'],
    ['M-Tab','Nxt Fld'], ['Tab','Nxt Col'],
    ['+','Widen'], ['-','Narrow']
  ]
  return key_labels
end
class Sqlc
  def initialize
    @window = VER::Window.root_window
    @form = Form.new @window

    #@todo = Sql.new "todo.yml"
    #@todo.load
    @db = Datasource.new
    @db.connect "testd.db"
  end
  def run
    title = "rbcurse"
    @header = ApplicationHeader.new @form, title, {:text2=>"Demo", :text_center=>"SQL Client"}
    status_row = RubyCurses::Label.new @form, {'text' => "", :row => Ncurses.LINES-4, :col => 0, :display_length=>70}
    @status_row = status_row
    # setting ENTER across all objects on a form
    @form.bind(:ENTER) {|f| status_row.text = f.help_text unless f.help_text.nil? }
    r = 1; c = 1;
    @data = [ ["No data"] ]
    data = @data
    colnames = %w[ Result ]

    ta_ht = 5
    t_width = 78
    sqlarea = TextArea.new @form do
      name   "sqlarea" 
      row  r 
      col  c
      width t_width
      height ta_ht
      title "Sql Query"
      title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
      help_text "Enter query and press Run or Meta-r"
    end
    sqlarea << "select * from contacts"
    buttrow = r+ta_ht+1 #Ncurses.LINES-4
    #create_table_actions atable, todo, data, categ.getvalue
    #save_cmd = @save_cmd
    b_run = Button.new @form do
      text "&Run"
      row buttrow
      col c
      help_text "Run query"
    end
    ## We use Action to create a button: to test out ampersand with MI and Button
    #clear_act = @clear_act
    b_clear = Button.new @form do
      #action new_act
      text "&Clear"
      row buttrow
      col c+10
      help_text "Clear query entry box "
      #bind(:ENTER) { status_row.text "New button adds a new row below current " }
    end
    b_clear.command { 
      sqlarea.remove_all
      sqlarea.focus
    }

    # using ampersand to set mnemonic

    b_construct = Button.new @form do
      text "Constr&uct"
      row buttrow
      col c+25
      #bind(:ENTER) { status_row.text "Deletes focussed row" }
      help_text "Select a table, select columns and press this to construct an SQL"
    end

    Button.button_layout [b_run, b_clear, b_construct], buttrow, startcol=5, cols=Ncurses.COLS-1, gap=5

    table_ht = 15
    atable = Table.new @form do
      name   "sqltable" 
      row  buttrow+1
      col  c
      width t_width
      height table_ht
      #title "A Table"
      #title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
      #set_data data, colnames
      #cell_editing_allowed true
      #editing_policy :EDITING_AUTO
      help_text "M-Tab for next field"
    end
    @atable = atable
    @data = data
    #atable.table_model.data = data

    tcm = atable.get_table_column_model
    b_run.command { 
      query =  sqlarea.get_text
      run_query query
    }
    #
    ## key bindings fo atable
    # column widths 
    app = self
    atable.configure() do
      #bind_key(330) { atable.remove_column(tcm.column(atable.focussed_col)) rescue ""  }
      bind_key(?+) {
        acolumn = atable.column atable.focussed_col()
        w = acolumn.width + 1
        acolumn.width w
        #atable.table_structure_changed
      }
      bind_key(?-) {
        acolumn = atable.column atable.focussed_col()
        w = acolumn.width - 1
        if w > 3
          acolumn.width w
          #atable.table_structure_changed
        end
      }
      bind_key(?>) {
        colcount = tcm.column_count-1
        #atable.move_column sel_col.value, sel_col.value+1 unless sel_col.value == colcount
        col = atable.focussed_col
        atable.move_column col, col+1 unless col == colcount
      }
      bind_key(?<) {
        col = atable.focussed_col
        atable.move_column col, col-1 unless col == 0
        #atable.move_column sel_col.value, sel_col.value-1 unless sel_col.value == 0
      }
      bind_key(?\M-h, app) {|tab,td| $log.debug " BIND... #{tab.class}, #{td.class}"; app.make_popup atable}
    end
    #keylabel = RubyCurses::Label.new @form, {'text' => "", "row" => r+table_ht+3, "col" => c, "color" => "yellow", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}
    #eventlabel = RubyCurses::Label.new @form, {'text' => "Events:", "row" => r+table_ht+6, "col" => c, "color" => "white", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}

    # report some events
    #atable.table_model.bind(:TABLE_MODEL_EVENT){|e| #eventlabel.text = "Event: #{e}"}
    #atable.get_table_column_model.bind(:TABLE_COLUMN_MODEL_EVENT){|e| eventlabel.text = "Event: #{e}"}
    atable.bind(:TABLE_TRAVERSAL_EVENT){|e| @header.text_right "Row #{e.newrow+1} of #{atable.row_count}" }

    tablist_ht = 6
    mylist = @db.get_data "select name from sqlite_master"
    $listdata = Variable.new mylist
        tablelist = Listbox.new @form do
          name   "tablelist" 
          row  1
          col  t_width+2
          width 20
          height tablist_ht
#         list mylist
          list_variable $listdata
          #selection_mode :SINGLE
          #show_selector true
          title "Tables"
          title_attrib 'reverse'
          help_text "Press ENTER to run * query, Space to select columns"
        end
        #tablelist.bind(:PRESS) { |alist| @status_row.text = "Selected #{alist.current_index}" }
        tablelist.list_selection_model().bind(:LIST_SELECTION_EVENT,tablelist) { |lsm, alist| @status_row.text = "Selected #{alist.current_index}" }

  collist = []
  $coldata = Variable.new collist
  columnlist = Listbox.new @form do
    name   "columnlist" 
    row  tablist_ht+2
    col  t_width+2
    width 20
    height 15
    #         list mylist
    list_variable $coldata
    #selection_mode :SINGLE
    #show_selector true
    title "Columns"
    title_attrib 'reverse'
    help_text "Press ENTER to append columns to sqlarea, Space to select"
  end
  tablelist.bind_key(32) {  
    @status_row.text = "Selected #{tablelist.get_content()[tablelist.current_index]}" 
    table = "#{tablelist.get_content()[tablelist.current_index]}" 
    columnlist.list_data_model.remove_all
    columnlist.list_data_model.insert 0, *@db.get_metadata(table)
  }
  tablelist.bind_key(13) {  
    @status_row.text = "Selected #{tablelist.get_content()[tablelist.current_index]}" 
    table = "#{tablelist.get_content()[tablelist.current_index]}" 
    run_query "select * from #{table}"
  }
  columnlist.bind_key(13) {  
    # append column name to sqlarea if ENTER pressed
    column = "#{columnlist.get_content()[columnlist.current_index]}" 
    sqlarea << "#{column},"
  }
  columnlist.bind_key(32) {  
    # select row
    columnlist.toggle_row_selection
    column = "#{columnlist.get_content()[columnlist.current_index]}" 
  }
    b_construct.command { 
    table = "#{tablelist.get_content()[tablelist.current_index]}" 
    indexes = columnlist.selected_rows()
    columns=[]
    indexes.each do |i|
      columns << columnlist.get_content()[i]
    end
    sql = "select #{columns.join(',')} from #{table}"
    sqlarea << sql
    }


    @form.repaint
    @window.wrefresh
    Ncurses::Panel.update_panels
    begin
    while((ch = @window.getchar()) != ?\C-q )
      #colcount = tcm.column_count-1
      s = keycode_tos ch
      #status_row.text = "Pressed #{ch} , #{s}"
      @form.handle_key(ch)

      @form.repaint
      @window.wrefresh
    end
    ensure
    @window.destroy if !@window.nil?
    end
  end
  def run_query sql
      #query =  sqlarea.get_text
      query =  sql
      begin
      @content = @db.get_data query
      if @content.nil?
        @status_row.text = "0 rows retrieved"
        return
      end
      #cw = @db.estimate_column_widths @atable.width, @db.columns
      @atable.set_data @content, @db.columns
      cw = @atable.estimate_column_widths @db.columns, @db.datatypes
      @atable.set_column_widths cw
      rescue => exc
        alert exc.to_s
        return
      end
      @status_row.text = "#{@content.size} rows retrieved"
      @atable.repaint
  end
  def create_table_actions atable, todo, data, categ
    #@new_act = Action.new("New Row", "mnemonic"=>"N") { 
    @new_act = Action.new("&New Row") { 
      mod = nil
      cc = atable.get_table_column_model.column_count
      if atable.row_count < 1
        frow = 0
      else
        frow = atable.focussed_row
        #frow += 1 # why ?
        mod = atable.get_value_at(frow,0) unless frow.nil?
      end
      tmp = [mod, 5, "", "TODO", Time.now]
      tm = atable.table_model
      tm.insert frow, tmp
      atable.set_focus_on frow
      @status_row.text = "Added a row. Please press Save before changing Category."
      alert("Added a row before current one. Use C-k to clear task.")
    }
    @new_act.accelerator "Alt-N"
    @save_cmd = lambda {
        todo.set_tasks_for_category categ, data
        todo.dump
        alert("Rewritten yaml file")
    }
    @del_cmd = lambda { 
      row = atable.focussed_row
      if !row.nil?
      if confirm("Do your really want to delete row #{row+1}?")== :YES
        tm = atable.table_model
        tm.delete_at row
      else
        @status_row.text = "Delete cancelled"
      end
      end
    }

  end
end
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
    # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG

    colors = Ncurses.COLORS
    $log.debug "START #{colors} colors  ---------"

    catch(:close) do
      t = Sqlc.new
      t.run
  end
  rescue => ex
  ensure
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
