//-----------------------FIRST-IN-FIRST-OUT-------------------------------------
module FIFO(clk,rst,wr,rd,din,dout,empt,full);
	input clk,rst,wr,rd;
	input [7:0] din;
	output reg [7:0] dout;
	output full,empt;
	integer i;
	reg [4:0] cnt =0;
	reg [7:0] mem [15:0];
	
	always@(posedge clk)begin
		if(rst)begin
			cnt<=0;
		end
		else
			begin
			if(wr && !full)begin
				mem[0] <= din;
                for (i = 16; i > 0; i = i - 1) begin
                 mem[i] <= mem[i-1];
            end
				cnt <= cnt+1;
				$display("[FIFO] :WRITE DATA = %0d,CNT = %0d",din,cnt);
			end
			else if(wr && full)
				$display("[FIFO] : WRITE IGNORED - FIFO IS FULL");
			
			if(rd && !empt)begin
				dout <=mem[cnt-1];
				$display("[FIFO] :READ DATA = %0d, CNT = %0d",mem[cnt-1],cnt);
				cnt<=cnt-1;
			end
			else if (rd && empt)begin
				$display("[FIFO] : READ IGNORED - FIFO IS EMPTY");
			end
		end	
	end		
	
	assign empt = (cnt == 0);
	assign full = (cnt == 15);	
endmodule

//--------------INTERFACE------------------------
interface fifo_if;
	logic clk,rst,rd,wr,full,empt;
	logic [7:0] din,dout;		
endinterface
//------------TRANSACTION------------------------
class transaction;
	rand bit oper;
	bit rd,wr,full,empt;
	bit [7:0] din,dout; 
	constraint operc{ oper dist{1 :/50 , 0 :/50};}
endclass
//-------------GENERATOR-------------------------
class generator;
	transaction t;
	mailbox #(transaction) mbx;
	int count = 0,i = 0;;
	event next,done;
	
	function new(mailbox #(transaction) mbx);
		this.mbx = mbx;
		t = new();
	endfunction
	
	task run();
		repeat(count)begin
			assert(t.randomize()) else $error("RANDMOZATION IS FAILED");
			i++;
			mbx.put(t);
			$display("[GEN] :OPER : %0d ITERATION : %0d",t.oper,i);
			@(next);
		end
	->done;
	endtask	
endclass
//------------DRIVER-------------------------
class driver;
	virtual fifo_if aif;
	transaction t;
	mailbox #(transaction) mbx;
	
	function new(mailbox #(transaction) mbx);
		this.mbx = mbx;
	endfunction
	task reset();
		aif.rst<=1;
		aif.rd<=0;
		aif.wr<=0;
		aif.din<=0;
		repeat(5) @( posedge aif.clk);
		aif.rst <=0;
		$display("[DRV] : DUT RESET DONE");
		$display("----------------------");
	endtask
	
	task write();
		@(posedge aif.clk);
		if(aif.full)
			$display("[DRV] : WRITE BLOCKED - FIFO IS FULL");
		aif.rd <= 0;
		aif.wr <= 1;
		aif.din <= $urandom_range(1,10);
		@(posedge aif.clk);
		aif.wr <= 0;
		$display("[DRV] : DATA WRITE ATTEMPTED : DATA = %0d",aif.din);
		@(posedge aif.clk);
	endtask
	task read();
		@(posedge aif.clk);
		if(aif.empt)
			$display("[DRV] : FIFO IS EMPTY"); 
		aif.wr<=0;
		aif.rd<=1;
		@(posedge aif.clk)
		aif.rd<=0;
		$display("[DRV] : DATA READ");
		@(posedge aif.clk);
	endtask
	
	task run();
		forever begin
			mbx.get(t);
			if(t.oper)
				write;
			else
				read();
		end
	endtask
endclass
//---------MONITOR--------------------------
class monitor;
    virtual fifo_if aif;
	transaction t;
	mailbox #(transaction) mbx;
	
	
	function new(mailbox #(transaction) mbx);
		this.mbx = mbx;
	endfunction
	
	task run();
		t = new();
		forever begin
			repeat(2) @(posedge aif.clk);
			t.wr = aif.wr;
			t.rd = aif.rd;
			t.din = aif.din;
			t.full = aif.full;
			t.empt = aif.empt;
			@(posedge aif.clk);
			t.dout = aif.dout;
			mbx.put(t);
			$display("[MON] : wr : %0d rd : %0d dout : %0d full : %0d empty : %0d ",t.wr,t.rd,t.dout,t.full,t.empt);
			
		end
	endtask
endclass
//----------------SCOREBOARD-----------------------------
class scoreboard;
	mailbox #(transaction) mbx;
	transaction t;
	event next;
	bit [7:0] din1 [$];
	bit [7:0] temp;
	int err =0;
	
	function new(mailbox #(transaction) mbx);
		this.mbx = mbx;
	endfunction
	
	task run();
		forever begin
			mbx.get(t);
			$display("[SCO] : wr : %0d rd : %0d dout : %0d full : %0d empty : %0d ",t.wr,t.rd,t.dout,t.full,t.empt);
			if(t.wr)begin
				if(!t.full)begin
					din1.push_front(t.din);
					$display("[SCO] : DATA STORED IN QUEUE : %0d",t.din);
				end
				else
					$display("FIFO IS FULL [SCO]");
				$display("--------------------");
			end
			
			if(t.rd)begin
				if(!t.empt)begin
					temp = din1.pop_back();
				if(t.dout == temp)
					$display("DATA MATCHED");
				else	begin
					$display(" DATA DOESN'T MATCHEDDOUT : %0d temp : %0d ",t.dout,temp);
					err++;
				end
				end
				else
					$display("FIFO IS EMPTY");
				$display("---------------------");
				end
			->next;
		end
	endtask
endclass
//---------------ENVIRONMENT-----------------------------
class environment;
	generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  mailbox #(transaction) gdmbx;  // Gen & Drv 
  mailbox #(transaction) msmbx;  // Mon & Sco
  virtual fifo_if aif;
  
  function new(virtual fifo_if aif);
    gdmbx = new();
    gen = new(gdmbx);
    drv = new(gdmbx);
    msmbx = new();
    mon = new(msmbx);
    sco = new(msmbx);
    this.aif = aif;
    drv.aif = this.aif;
    mon.aif = this.aif;
    gen.next = sco.next;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);  
    $display("---------------------------------------------");
    $display("Error Count :%0d", sco.err);
    $display("---------------------------------------------");
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass

//----------------------TESTBENCH---------------------------------------

module tb;
    
  fifo_if aif();
  FIFO dut (aif.clk, aif.rst, aif.wr, aif.rd, aif.din, aif.dout, aif.empt, aif.full);
    
  initial begin
    aif.clk <= 0;
  end
    
  always #10 aif.clk <= ~aif.clk;
    
  environment env;
    
  initial begin
    env = new(aif);
    env.gen.count = 10;
    env.run();
  end
    
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
   
endmodule

