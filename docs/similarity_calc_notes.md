similarity\_calc testbench - how it works 



1. This testbench verify the similarity\_calc module. In this testbench 5 different patterns is used to simulate 5 situation. The score is IoU (intersection-over-union): overlap × 100 / union  

2. In tests 3, 4, and 5, canvas\_bit and target\_bit depend on which cell the DUT is currently sweeping. The DUT drives out an address (cell\_x, cell\_y) and the testbench must respond with the right bit for that cell. This is a reactive driver, built with always @(posedge clk) and non-blocking assignment (<=). The <= gives a one-cycle delay for free, which models the real canvas BRAM's read latency (data valid one clock after the address).

3. Before checking computed score for each test @(posedge score\_ready) is used to allow the system shift the FSM to S\_DONE from S\_IDLE. Which lets score\_ready go high before check\_score runs . 

4. Before any test pattern is used, I need to determine the input value (canvas\_bit and target\_bit). This allow me to forecast the overlap, union\_w and score. Hence, how I discover bug in this RTL design, shows wrong overlap value during certain situation. The patterns are defined by simple coordinate rules (e.g. cell\_x < 40), chosen so the cell counts are hand-countable and the expected score is predictable — verifiability, not realism. Being able to forecast overlap, union, and score by hand is exactly what let me detect the DUT disagreeing.

5. This method exposed a real bug: for bounded-target patterns (MODE\_SCRIBBLE, MODE\_MATCH) the DUT undercounts overlap at target row boundaries, giving wrong scores (48 vs 50, 95 vs 100). Full analysis in bug\_log.md.

&#x20;



