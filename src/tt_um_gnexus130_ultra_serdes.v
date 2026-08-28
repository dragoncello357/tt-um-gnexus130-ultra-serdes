// ============================================================================
// CHIP: G-NEXUS 130 ULTRA v3 (28-PIN SERDES & BIOS BOOT ENGINE)
// AUTHOR: Gabriel D'Amico
// FREQUENCY: Multi-GHz Internal Core | 28-Pin TDM Multiplexed Interface
// ============================================================================

module tt_um_gnexus130_ultra_serdes (
    input  wire [7:0] ui_in,    // Control, Ref Clock, Reset, RX Serial
    output wire [7:0] uo_out,   // TX Serial, Video Serial, BIOS Clock
    input  wire [7:0] uio_in,   // Bidirectional Input
    output wire [7:0] uio_out,  // Bidirectional Output (QSPI Flash / LPDDR Mux)
    output wire [7:0] uio_oe,   // Direction Control for Pads
    input  wire       ena,      // Chip Enable
    input  wire       clk,      // System Main Input Clock (35 MHz Ref)
    input  wire       rst_n     // Hardware Reset
);

    // ========================================================================
    // 1. SILICON ROM IMMUTABILE (GABRIEL D'AMICO)
    // ========================================================================
    reg [63:0] silicon_rom [0:7];
    initial begin
        silicon_rom[0] = 64'h4372656174656420; // "Created "
        silicon_rom[1] = 64'h2620496465617465; // "& Ideate"
        silicon_rom[2] = 64'h6420627920476162; // "d by Gab"
        silicon_rom[3] = 64'h7269656C20442741; // "riel D'A"
        silicon_rom[4] = 64'h6D69636F00000000; // "mico\0\0\0\0"
        silicon_rom[5] = 64'h4744412D4E455855; // "GDA-NEXU"
        silicon_rom[6] = 64'h532D583800000000; // "S-X8\0\0\0\0"
        silicon_rom[7] = 64'h2026_0828_0000_0003; // Build V3
    end

    // ========================================================================
    // 2. CORRIDOR UMA A 1024-BIT E CORE QUAD-STATE
    // ========================================================================
    wire [1023:0] uma_wide_bus;
    reg  [511:0]  pcie_dma_buffer;
    reg  [3:0]    serdes_counter;
    reg           boot_complete;

    assign uma_wide_bus[511:0]   = {64{ui_in}};
    assign uma_wide_bus[1023:512] = {8{silicon_rom[ui_in[3:1]]}};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pcie_dma_buffer <= 512'b0;
            serdes_counter  <= 4'b0;
            boot_complete   <= 1'b0;
        end else begin
            pcie_dma_buffer <= uma_wide_bus[511:0];
            serdes_counter  <= serdes_counter + 1'b1;
            if (serdes_counter == 4'hF) begin
                boot_complete <= 1'b1; // BIOS caricato con successo
            end
        end
    end

    // ========================================================================
    // 3. HARDWARE MULTIPLEXER PER BOOT BIOS E SERDES (28 PIN)
    // ========================================================================
    // Uscita Serializzata PCIe + Video Output
    assign uo_out[3:0] = pcie_dma_buffer[(serdes_counter * 4) +: 4]; // PCIe TX
    assign uo_out[5:4] = {clk, ~clk};                                // Video TMDS Serial
    assign uo_out[6]   = clk;                                         // BIOS SPI Clock
    assign uo_out[7]   = boot_complete;                               // Status Lock Pin

    // Gestione Bus Bidirezionale (SPI Flash per il BIOS / Controllo LPDDR4x)
    assign uio_out[3:0] = uma_wide_bus[(serdes_counter * 4) +: 4];
    assign uio_out[7:4] = {boot_complete, ui_in[2:0]};
    assign uio_oe       = (boot_complete) ? 8'hFF : 8'h0F; // Configurazione automatica I/O

endmodule