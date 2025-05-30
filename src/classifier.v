module classifier (
    input  wire        clk,
    input  wire        reset,
    input  wire        current_detection,
    output reg  [1:0]  event_out,
    input  wire [7:0]  class_a_thresh_in,
    input  wire [7:0]  class_b_thresh_in,
    input  wire [15:0] timeout_period_in
);

    // Event encoding: C = 2'b00, B = 2'b01, A = 2'b10
    localparam [1:0] EVENT_C = 2'b00;
    localparam [1:0] EVENT_B = 2'b01;
    localparam [1:0] EVENT_A = 2'b10;

    // Constants
    localparam SAMPLE_RATE                   = 2000;
    localparam MAX_EXCITABILITY              = 100;
    localparam SATURATION_EXCITABILITY       = 10;
    localparam ICTAL_REFRACTORY_PERIOD       = 10 * SAMPLE_RATE;
    localparam DECAY_STEP_PERIOD             = SAMPLE_RATE;
    localparam COUNTER_CONFIRMATION_A_THRESH = 5;
    localparam COUNTER_CONFIRMATION_B_THRESH = 1;

    // Registers
    reg  [1:0] current_event;
    reg  [1:0] previous_event;

    reg  [31:0] class_a_threshold;
    reg  [31:0] class_b_threshold;
    reg  [31:0] timeout_period;

    reg  [31:0] excitability;
    reg  [31:0] sample_count;
    reg  [31:0] last_peak_sample_count;
    reg  [31:0] last_event_sample_count;
    reg  [31:0] counter_confirmation_a;
    reg  [31:0] counter_confirmation_b;
    reg  [31:0] last_a_section_end;
    reg  [31:0] last_b_section_end;
    reg  [31:0] event_start;
    reg  [31:0] k;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_event          <= EVENT_C;
            previous_event         <= EVENT_C;
            class_a_threshold      <= 5;
            class_b_threshold      <= 1;
            timeout_period         <= 5 * SAMPLE_RATE;
            excitability           <= 0;
            sample_count           <= 0;
            last_peak_sample_count <= 0;
            last_event_sample_count <= 0;
            counter_confirmation_a <= 0;
            counter_confirmation_b <= 0;
            last_a_section_end     <= 0;
            last_b_section_end     <= 0;
            event_start            <= 0;
            event_out              <= EVENT_C;
        end else begin
            // Update thresholds from inputs
            class_a_threshold <= class_a_thresh_in;
            class_b_threshold <= class_b_thresh_in;
            timeout_period    <= timeout_period_in;

            sample_count <= sample_count + 1;

            if (current_detection) begin
                excitability <= excitability + MAX_EXCITABILITY;
                if (excitability > (SATURATION_EXCITABILITY * MAX_EXCITABILITY))
                    excitability <= SATURATION_EXCITABILITY * MAX_EXCITABILITY;
                last_event_sample_count <= sample_count;
                last_peak_sample_count  <= sample_count;
            end else begin
                k = sample_count - last_peak_sample_count;
                if (k >= DECAY_STEP_PERIOD)
                    excitability <= 0;
            end

            // Timeout reversion to class C
            if ((sample_count - last_event_sample_count) > timeout_period)
                current_event <= EVENT_C;

            // Classification logic
            if (excitability >= (class_a_threshold * MAX_EXCITABILITY)) begin
                counter_confirmation_a <= counter_confirmation_a + 1;
                if (counter_confirmation_a > COUNTER_CONFIRMATION_A_THRESH) begin
                    if (current_event != EVENT_A) begin
                        previous_event <= current_event;
                        event_start    <= sample_count;
                    end
                    current_event <= EVENT_A;
                end
            end else if (excitability >= (class_b_threshold * MAX_EXCITABILITY)) begin
                if ((current_event != EVENT_B) && ((sample_count - last_a_section_end) > ICTAL_REFRACTORY_PERIOD)) begin
                    previous_event <= current_event;
                    current_event  <= EVENT_B;
                    event_start    <= sample_count;
                end else begin
                    counter_confirmation_b <= counter_confirmation_b + 1;
                end
            end else begin
                if ((current_event == EVENT_A) && ((sample_count - last_a_section_end) > ICTAL_REFRACTORY_PERIOD)) begin
                    if (excitability > (class_b_threshold * MAX_EXCITABILITY))
                        current_event <= EVENT_B;
                    else
                        current_event <= EVENT_C;
                end else begin
                    if (previous_event != EVENT_C) begin
                        counter_confirmation_a <= 0;
                        counter_confirmation_b <= 0;
                        if (current_event == EVENT_B)
                            last_b_section_end <= sample_count;
                        else if (current_event == EVENT_A)
                            last_a_section_end <= sample_count;
                        previous_event <= current_event;
                    end
                    current_event <= EVENT_C;
                end
            end

            // Output event
            event_out <= current_event;
        end
    end
endmodule
