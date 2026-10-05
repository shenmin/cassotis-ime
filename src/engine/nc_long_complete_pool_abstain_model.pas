unit nc_long_complete_pool_abstain_model;

interface

uses
    nc_long_ranker_features;

const
    c_long_complete_pool_abstain_feature_count: Integer = 49;
    c_long_complete_pool_abstain_tree_count: Integer = 60;
    c_long_complete_pool_abstain_score_scale: Double = 100000000.0;
    c_long_complete_pool_abstain_reference_score: Int64 = -74311123;
    c_long_complete_pool_abstain_reference_score_low: Int64 = -80525002;
    c_long_complete_pool_abstain_reference_score_high: Int64 = 40002955;
    c_long_complete_pool_abstain_reference_score_mixed: Int64 = -87156184;

function long_complete_pool_abstain_score(
    const features: TncLongFinalAbstainFeatures): Int64;
function long_complete_pool_abstain_self_test: Boolean;

implementation

{ Unified long-sentence ranker confidence gate. The generated unit has no LightGBM runtime dependency.
  Training report SHA-256: D32FADF5829D0D57588BDED0863D25E7877B71842529CEB89B5B461D0BBFE823
  LightGBM model SHA-256: A969295A6635E0D3BDCED69AA5F22CBE31EE01810EE2AFFE718F97D6A88D03F5 }

function long_complete_pool_abstain_tree_0(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 90955716.000000015 then
    begin
        if features.ranker_top_char_lm_gain <= 99.500000000000014 then
        begin
            if features.ranker_top_word_lm_gain <= 232.50000000000003 then
            begin
                Result := 0.69037542587530765;
            end
            else
            begin
                Result := 0.7295819363302235;
            end;
        end
        else
        begin
            if features.ranker_top_word_lm_bonus <= 436.50000000000006 then
            begin
                if features.ranker_top_char_lm_gain <= 775.50000000000011 then
                begin
                    Result := 0.7188332250513958;
                end
                else
                begin
                    Result := 0.75204722746391539;
                end;
            end
            else
            begin
                Result := 0.76250664737589835;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 165682465.00000003 then
        begin
            Result := 0.77537652188588335;
        end
        else
        begin
            Result := 0.8004250054798856;
        end;
    end;
end;

function long_complete_pool_abstain_tree_1(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 90955716.000000015 then
    begin
        if features.ranker_top_pool_source_kind <= 2.0000000000000004 then
        begin
            if features.ranker_top_pair_evidence <= 1125.0000000000002 then
            begin
                Result := -0.061516011100866637;
            end
            else
            begin
                Result := -0.02629608794513311;
            end;
        end
        else
        begin
            if features.ranker_second_margin <= 95473866.000000015 then
            begin
                Result := -0.022118118874091791;
            end
            else
            begin
                if features.ranker_top_margin <= 14363686.000000002 then
                begin
                    Result := -0.029965653324653264;
                end
                else
                begin
                    Result := 0.01518398473773473;
                end;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 165682465.00000003 then
        begin
            Result := 0.02060585174875993;
        end
        else
        begin
            Result := 0.047559479219756132;
        end;
    end;
end;

function long_complete_pool_abstain_tree_2(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_char_lm_gain <= 328.50000000000006 then
    begin
        if features.ranker_top_word_lm_gain <= 198.50000000000003 then
        begin
            if features.ranker_top_pair_evidence <= 5851.5000000000009 then
            begin
                if features.ranker_top_legacy_rank <= 11.500000000000002 then
                begin
                    Result := -0.0499047177182807;
                end
                else
                begin
                    Result := 0.041218653583036391;
                end;
            end
            else
            begin
                Result := -0.00083487063163298358;
            end;
        end
        else
        begin
            Result := -0.0055354402633558146;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 788579870.00000012 then
        begin
            Result := 0.00055133054400376385;
        end
        else
        begin
            if features.ranker_top_over_legacy_margin <= 55190983.000000007 then
            begin
                Result := -0.001949237164608828;
            end
            else
            begin
                Result := 0.03418331219965072;
            end;
        end;
    end;
end;

function long_complete_pool_abstain_tree_3(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 90955716.000000015 then
    begin
        if features.ranker_top_char_lm_gain <= 99.500000000000014 then
        begin
            if features.ranker_top_word_lm_gain <= 232.50000000000003 then
            begin
                Result := -0.053746269187420238;
            end
            else
            begin
                if features.ranker_top_char_lm_score <= -5402.9999999999991 then
                begin
                    Result := 0.011045251593575793;
                end
                else
                begin
                    Result := -0.042003557816084405;
                end;
            end;
        end
        else
        begin
            if features.ranker_top_word_lm_bonus <= 465.50000000000006 then
            begin
                Result := -0.01992907262904817;
            end
            else
            begin
                Result := 0.0057785746452877667;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 165682465.00000003 then
        begin
            Result := 0.020105897066986563;
        end
        else
        begin
            Result := 0.045965670409418243;
        end;
    end;
end;

function long_complete_pool_abstain_tree_4(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_over_legacy_margin <= 114735959.50000001 then
    begin
        if features.ranker_top_char_lm_gain <= 416.50000000000006 then
        begin
            if features.ranker_top_word_lm_gain <= 12.500000000000002 then
            begin
                Result := -0.045308400291886736;
            end
            else
            begin
                if features.ranker_top_char_lm_gain <= 108.50000000000001 then
                begin
                    Result := -0.029131678476207762;
                end
                else
                begin
                    Result := 0.0044312209585550379;
                end;
            end;
        end
        else
        begin
            if features.ranker_score_range <= 995207626.00000012 then
            begin
                Result := 0.00075581751137562359;
            end
            else
            begin
                Result := 0.051997761329329012;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_word_lm_bonus <= 535.50000000000011 then
        begin
            Result := 0.011607982782119566;
        end
        else
        begin
            Result := 0.037344195999231659;
        end;
    end;
end;

function long_complete_pool_abstain_tree_5(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 90955716.000000015 then
    begin
        if features.ranker_top_char_lm_gain <= 328.50000000000006 then
        begin
            if features.ranker_top_word_lm_gain <= 12.500000000000002 then
            begin
                Result := -0.043916774828105201;
            end
            else
            begin
                Result := -0.019780456895744689;
            end;
        end
        else
        begin
            if features.legacy_top_pair_evidence <= 1246.5000000000002 then
            begin
                if features.ranker_second_margin <= 46509634.500000007 then
                begin
                    Result := -0.03491051649722967;
                end
                else
                begin
                    Result := -0.001890726987082443;
                end;
            end
            else
            begin
                Result := 0.014854069352071526;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 165682465.00000003 then
        begin
            Result := 0.01813404501006553;
        end
        else
        begin
            Result := 0.044266498523791151;
        end;
    end;
end;

function long_complete_pool_abstain_tree_6(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 90955716.000000015 then
    begin
        if features.ranker_top_char_lm_gain <= 775.50000000000011 then
        begin
            if features.ranker_top_word_lm_gain <= 71.000000000000014 then
            begin
                Result := -0.035495822790256606;
            end
            else
            begin
                if features.ranker_top_char_lm_gain <= -79.499999999999986 then
                begin
                    Result := -0.039185022138461409;
                end
                else
                begin
                    Result := -0.0039728826670285275;
                end;
            end;
        end
        else
        begin
            if features.legacy_top_char_lm_score <= -6041.4999999999991 then
            begin
                Result := -0.015805254081297623;
            end
            else
            begin
                Result := 0.020578535452501316;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 161232144.00000003 then
        begin
            Result := 0.019058782565299054;
        end
        else
        begin
            Result := 0.044005844959093307;
        end;
    end;
end;

function long_complete_pool_abstain_tree_7(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 90955716.000000015 then
    begin
        if features.ranker_top_char_lm_gain <= 99.500000000000014 then
        begin
            if features.ranker_top_word_lm_gain <= 232.50000000000003 then
            begin
                Result := -0.046450016805707643;
            end
            else
            begin
                if features.ranker_second_score <= -29995045.499999996 then
                begin
                    Result := 0.025679028566758546;
                end
                else
                begin
                    Result := -0.031388153660710405;
                end;
            end;
        end
        else
        begin
            if features.ranker_top_word_lm_bonus <= 443.50000000000006 then
            begin
                Result := -0.019741836381562822;
            end
            else
            begin
                Result := 0.0043028665721410245;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 161232144.00000003 then
        begin
            Result := 0.017976239844765186;
        end
        else
        begin
            Result := 0.041925008338669807;
        end;
    end;
end;

function long_complete_pool_abstain_tree_8(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 98394364.500000015 then
    begin
        if features.ranker_top_char_lm_gain <= 759.50000000000011 then
        begin
            if features.ranker_top_word_lm_gain <= 71.000000000000014 then
            begin
                Result := -0.031716992249676688;
            end
            else
            begin
                if features.ranker_top_margin <= 67890250.500000015 then
                begin
                    Result := -0.014029564932789869;
                end
                else
                begin
                    Result := 0.016784168457821685;
                end;
            end;
        end
        else
        begin
            if features.legacy_top_char_lm_score <= -7070.4999999999991 then
            begin
                Result := -0.03798777291714877;
            end
            else
            begin
                Result := 0.013302483341313454;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 824552830.00000012 then
        begin
            Result := 0.015062552009138443;
        end
        else
        begin
            Result := 0.039743479232545856;
        end;
    end;
end;

function long_complete_pool_abstain_tree_9(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 90955716.000000015 then
    begin
        if features.ranker_top_char_lm_gain <= 328.50000000000006 then
        begin
            Result := -0.02648569554820154;
        end
        else
        begin
            if features.ranker_score_range <= 594090254.00000012 then
            begin
                if features.ranker_second_margin <= 74769712.000000015 then
                begin
                    Result := -0.052410818688071112;
                end
                else
                begin
                    Result := 0.014570954238784236;
                end;
            end
            else
            begin
                Result := 0.0027587038632338125;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_chain_rank <= 1.5000000000000002 then
        begin
            if features.ranker_top_margin <= 165682465.00000003 then
            begin
                Result := 0.02038484488568133;
            end
            else
            begin
                Result := 0.041996555739797665;
            end;
        end
        else
        begin
            Result := -0.043973335001033148;
        end;
    end;
end;

function long_complete_pool_abstain_tree_10(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_char_lm_gain <= 328.50000000000006 then
    begin
        if features.ranker_top_word_lm_gain <= 8.5000000000000018 then
        begin
            if features.legacy_top_ranker_score <= -71321005.999999985 then
            begin
                Result := -0.055916089820164196;
            end
            else
            begin
                Result := -0.026717707810405576;
            end;
        end
        else
        begin
            if features.ranker_top_char_lm_gain <= 108.50000000000001 then
            begin
                Result := -0.019530975349190759;
            end
            else
            begin
                Result := 0.010533362349519335;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_word_lm_bonus <= 535.50000000000011 then
        begin
            if features.ranker_top_score <= 119818113.50000001 then
            begin
                Result := -0.0059461852039256581;
            end
            else
            begin
                Result := 0.015212992848077518;
            end;
        end
        else
        begin
            Result := 0.030487995679024337;
        end;
    end;
end;

function long_complete_pool_abstain_tree_11(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 96538916.500000015 then
    begin
        if features.ranker_top_char_lm_gain <= 759.50000000000011 then
        begin
            if features.ranker_top_pair_evidence <= 1153.5000000000002 then
            begin
                Result := -0.033980977116614748;
            end
            else
            begin
                if features.ranker_top_char_lm_gain <= -43.499999999999993 then
                begin
                    Result := -0.030824493966133064;
                end
                else
                begin
                    Result := -0.0028742825257372959;
                end;
            end;
        end
        else
        begin
            if features.legacy_top_ranker_score <= 26407099.500000004 then
            begin
                Result := -0.0090462821389326927;
            end
            else
            begin
                Result := 0.026810102564432073;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 824552830.00000012 then
        begin
            Result := 0.013116014454116063;
        end
        else
        begin
            Result := 0.037969321023304782;
        end;
    end;
end;

function long_complete_pool_abstain_tree_12(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 86065055.000000015 then
    begin
        if features.ranker_top_char_lm_gain <= 99.500000000000014 then
        begin
            Result := -0.02794941980192852;
        end
        else
        begin
            if features.ranker_top_margin <= 22492761.000000004 then
            begin
                Result := -0.022284554747231258;
            end
            else
            begin
                if features.ranker_second_margin <= 62992604.000000007 then
                begin
                    Result := -0.016674398005064043;
                end
                else
                begin
                    Result := 0.011717297181833577;
                end;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 165682465.00000003 then
        begin
            if features.ranker_top_char_lm_score <= -5304.4999999999991 then
            begin
                Result := -0.0034319661716523927;
            end
            else
            begin
                Result := 0.024463496220403964;
            end;
        end
        else
        begin
            Result := 0.040578678459311769;
        end;
    end;
end;

function long_complete_pool_abstain_tree_13(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 100773925.00000001 then
    begin
        if features.ranker_top_char_lm_gain <= 209.50000000000003 then
        begin
            Result := -0.024312426428685072;
        end
        else
        begin
            if features.ranker_top_pair_evidence <= 1.0000000180025095E-35 then
            begin
                if features.ranker_top_pool_rank <= 2.5000000000000004 then
                begin
                    Result := -0.037679540469181989;
                end
                else
                begin
                    if features.legacy_top_chain_rank <= 1.5000000000000002 then
                    begin
                        Result := 0.001290256380815237;
                    end
                    else
                    begin
                        Result := -0.09819352708552892;
                    end;
                end;
            end
            else
            begin
                Result := 0.0044425312140583071;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 165682465.00000003 then
        begin
            Result := 0.016815126434872148;
        end
        else
        begin
            Result := 0.038830811119379985;
        end;
    end;
end;

function long_complete_pool_abstain_tree_14(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 98394364.500000015 then
    begin
        if features.ranker_top_char_lm_gain <= -79.499999999999986 then
        begin
            Result := -0.03508036913756557;
        end
        else
        begin
            if features.ranker_top_word_lm_bonus <= 390.50000000000006 then
            begin
                if features.ranker_top_char_lm_gain <= 384.00000000000006 then
                begin
                    Result := -0.028125108171563679;
                end
                else
                begin
                    if features.ranker_top_consensus_gain <= -1.0000000180025095E-35 then
                    begin
                        Result := -0.0013544210767420732;
                    end
                    else
                    begin
                        Result := -0.05284590413604244;
                    end;
                end;
            end
            else
            begin
                Result := 0.0025735804324427407;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 824552830.00000012 then
        begin
            Result := 0.010806724533724029;
        end
        else
        begin
            Result := 0.035308236963216319;
        end;
    end;
end;

function long_complete_pool_abstain_tree_15(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 88800188.000000015 then
    begin
        if features.ranker_top_char_lm_gain <= 217.50000000000003 then
        begin
            Result := -0.023371563265514567;
        end
        else
        begin
            if features.ranker_score_range <= 645553076.50000012 then
            begin
                Result := -0.023151470338487089;
            end
            else
            begin
                if features.ranker_top_pair_evidence <= 1237.5000000000002 then
                begin
                    if features.ranker_top_char_lm_gain <= 352.50000000000006 then
                    begin
                        Result := -0.047276275644302902;
                    end
                    else
                    begin
                        Result := -0.0022567951722295867;
                    end;
                end
                else
                begin
                    Result := 0.011777207751485528;
                end;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 824552830.00000012 then
        begin
            Result := 0.0091112788325758507;
        end
        else
        begin
            Result := 0.033311458507101904;
        end;
    end;
end;

function long_complete_pool_abstain_tree_16(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 90955716.000000015 then
    begin
        if features.ranker_top_char_lm_gain <= 328.50000000000006 then
        begin
            if features.ranker_top_word_lm_gain <= 182.50000000000003 then
            begin
                if features.ranker_top_legacy_rank <= 9.5000000000000018 then
                begin
                    Result := -0.031887215106013042;
                end
                else
                begin
                    Result := 0.004603644626148244;
                end;
            end
            else
            begin
                Result := -0.008518060588449991;
            end;
        end
        else
        begin
            if features.ranker_second_margin <= 84375795.500000015 then
            begin
                Result := -0.010329812614232825;
            end
            else
            begin
                Result := 0.0090713059969386306;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 165682465.00000003 then
        begin
            Result := 0.014928893310046012;
        end
        else
        begin
            Result := 0.036742108894960893;
        end;
    end;
end;

function long_complete_pool_abstain_tree_17(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 100773925.00000001 then
    begin
        if features.ranker_top_char_lm_gain <= 759.50000000000011 then
        begin
            if features.ranker_second_margin <= 82851501.500000015 then
            begin
                Result := -0.025428124023753003;
            end
            else
            begin
                if features.ranker_top_pair_evidence <= 3138.0000000000005 then
                begin
                    Result := -0.013598595750816187;
                end
                else
                begin
                    Result := 0.012813249781265712;
                end;
            end;
        end
        else
        begin
            if features.legacy_top_ranker_score <= 26407099.500000004 then
            begin
                Result := -0.007784987861826958;
            end
            else
            begin
                Result := 0.024860213983835835;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 824552830.00000012 then
        begin
            Result := 0.011696025156804624;
        end
        else
        begin
            Result := 0.033558295372931812;
        end;
    end;
end;

function long_complete_pool_abstain_tree_18(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_char_lm_gain <= 505.50000000000006 then
    begin
        if features.ranker_top_word_lm_gain <= 8.5000000000000018 then
        begin
            Result := -0.024724687747716415;
        end
        else
        begin
            if features.ranker_top_char_lm_gain <= 74.500000000000014 then
            begin
                if features.ranker_third_score <= 183323775.50000003 then
                begin
                    Result := -0.0071770321832322235;
                end
                else
                begin
                    Result := -0.047241496191849065;
                end;
            end
            else
            begin
                Result := 0.010217707816232734;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_score <= 207252341.50000003 then
        begin
            if features.ranker_top_consensus_gain <= -1.0000000180025095E-35 then
            begin
                Result := 0.0059337801925902515;
            end
            else
            begin
                Result := -0.032214240643468249;
            end;
        end
        else
        begin
            Result := 0.027068614502285846;
        end;
    end;
end;

function long_complete_pool_abstain_tree_19(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_over_legacy_margin <= 120960834.50000001 then
    begin
        if features.ranker_second_margin <= 86318752.000000015 then
        begin
            if features.ranker_score_range <= 629263785.00000012 then
            begin
                Result := -0.034154951061149817;
            end
            else
            begin
                Result := -0.010395979504000667;
            end;
        end
        else
        begin
            if features.ranker_top_over_legacy_margin <= 27380728.500000004 then
            begin
                Result := -0.014536160458317638;
            end
            else
            begin
                if Ord(features.ranker_top_dictionary) <= 1.0000000180025095E-35 then
                begin
                    Result := 0.016850434683057133;
                end
                else
                begin
                    Result := -0.022205370793277779;
                end;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 883012073.00000012 then
        begin
            Result := 0.0094202056659433674;
        end
        else
        begin
            Result := 0.026915727990405196;
        end;
    end;
end;

function long_complete_pool_abstain_tree_20(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 98394364.500000015 then
    begin
        if features.ranker_top_char_lm_gain <= 99.500000000000014 then
        begin
            Result := -0.020765319891875734;
        end
        else
        begin
            if features.ranker_top_score <= -16862532.999999996 then
            begin
                Result := -0.017981629072181145;
            end
            else
            begin
                if features.ranker_top_margin <= 25163538.000000004 then
                begin
                    Result := -0.011835903290201923;
                end
                else
                begin
                    Result := 0.0092133350241051602;
                end;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 824552830.00000012 then
        begin
            if features.ranker_top_pool_rank <= 3.5000000000000004 then
            begin
                Result := -0.0089182536485479195;
            end
            else
            begin
                Result := 0.028162530307410876;
            end;
        end
        else
        begin
            Result := 0.031961911705095228;
        end;
    end;
end;

function long_complete_pool_abstain_tree_21(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 90955716.000000015 then
    begin
        if features.ranker_top_char_lm_gain <= 775.50000000000011 then
        begin
            if features.ranker_top_word_lm_gain <= 12.500000000000002 then
            begin
                if features.legacy_top_ranker_score <= 239801931.50000003 then
                begin
                    Result := -0.028115279072653869;
                end
                else
                begin
                    Result := 0.0027122409305501195;
                end;
            end
            else
            begin
                Result := -0.0053276559483713308;
            end;
        end
        else
        begin
            if features.legacy_top_ranker_score <= 216505955.00000003 then
            begin
                Result := -0.00097683158643073519;
            end
            else
            begin
                Result := 0.039605241084541741;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 824552830.00000012 then
        begin
            Result := 0.0088356034514102972;
        end
        else
        begin
            Result := 0.030123060666392327;
        end;
    end;
end;

function long_complete_pool_abstain_tree_22(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 98394364.500000015 then
    begin
        if features.ranker_second_margin <= 86318752.000000015 then
        begin
            if features.ranker_score_range <= 645553076.50000012 then
            begin
                Result := -0.03085850322264452;
            end
            else
            begin
                Result := -0.0084575565855514959;
            end;
        end
        else
        begin
            if features.ranker_top_margin <= 28401906.500000004 then
            begin
                if features.ranker_third_score <= -154354806.99999997 then
                begin
                    Result := 0.011258309439127662;
                end
                else
                begin
                    Result := -0.025204862333194123;
                end;
            end
            else
            begin
                Result := 0.0091621145375851334;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 824552830.00000012 then
        begin
            Result := 0.0062307977350664102;
        end
        else
        begin
            Result := 0.030548705538963886;
        end;
    end;
end;

function long_complete_pool_abstain_tree_23(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 100773925.00000001 then
    begin
        if features.ranker_top_char_lm_gain <= 209.50000000000003 then
        begin
            Result := -0.017595149278110497;
        end
        else
        begin
            if features.legacy_top_pair_evidence <= 1246.5000000000002 then
            begin
                Result := -0.0090508055766403157;
            end
            else
            begin
                Result := 0.01130137768339181;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 201291687.50000003 then
        begin
            if features.ranker_second_margin <= 13438283.500000002 then
            begin
                if features.ranker_top_char_lm_gain <= 551.50000000000011 then
                begin
                    Result := -0.048234275729211185;
                end
                else
                begin
                    Result := 0.014513623462598468;
                end;
            end
            else
            begin
                Result := 0.018836957883770329;
            end;
        end
        else
        begin
            Result := 0.036926740953354242;
        end;
    end;
end;

function long_complete_pool_abstain_tree_24(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 103046290.50000001 then
    begin
        if features.ranker_top_char_lm_gain <= 775.50000000000011 then
        begin
            if features.ranker_top_word_lm_gain <= 12.500000000000002 then
            begin
                if features.ranker_second_margin <= 5639071.0000000009 then
                begin
                    Result := -0.062571272865068223;
                end
                else
                begin
                    if features.ranker_third_score <= 13508860.500000002 then
                    begin
                        Result := -0.027250096784703807;
                    end
                    else
                    begin
                        Result := -0.0054825408835071148;
                    end;
                end;
            end
            else
            begin
                Result := -0.004199455110122075;
            end;
        end
        else
        begin
            Result := 0.0070030367295176666;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 157333208.00000003 then
        begin
            Result := 0.010703673750438474;
        end
        else
        begin
            Result := 0.032375025595792459;
        end;
    end;
end;

function long_complete_pool_abstain_tree_25(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 98394364.500000015 then
    begin
        if features.ranker_top_margin <= 28401906.500000004 then
        begin
            Result := -0.017076107912020022;
        end
        else
        begin
            if features.ranker_second_margin <= 84375795.500000015 then
            begin
                if features.ranker_score_range <= 522370305.00000006 then
                begin
                    Result := -0.044941703217808771;
                end
                else
                begin
                    Result := -0.0074108478249685153;
                end;
            end
            else
            begin
                Result := 0.0097696647540300961;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 824552830.00000012 then
        begin
            if features.ranker_top_legacy_rank <= 3.5000000000000004 then
            begin
                Result := -0.011216052265933685;
            end
            else
            begin
                Result := 0.026097109703677891;
            end;
        end
        else
        begin
            Result := 0.028735333831224223;
        end;
    end;
end;

function long_complete_pool_abstain_tree_26(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 153841953.00000003 then
    begin
        if features.ranker_top_margin <= 60047865.000000007 then
        begin
            if features.ranker_top_char_lm_gain <= 863.50000000000011 then
            begin
                Result := -0.013889387478741362;
            end
            else
            begin
                Result := 0.0058694500706661804;
            end;
        end
        else
        begin
            if features.ranker_second_margin <= 150972620.00000003 then
            begin
                if features.legacy_top_consensus_support <= 889.50000000000011 then
                begin
                    Result := -0.014601512166559583;
                end
                else
                begin
                    if features.ranker_top_char_lm_score <= -4537.4999999999991 then
                    begin
                        Result := -0.0029370045761288252;
                    end
                    else
                    begin
                        Result := 0.02305851667049166;
                    end;
                end;
            end
            else
            begin
                Result := 0.027253242121051111;
            end;
        end;
    end
    else
    begin
        Result := 0.029503884500107401;
    end;
end;

function long_complete_pool_abstain_tree_27(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 103046290.50000001 then
    begin
        if features.ranker_second_margin <= 82851501.500000015 then
        begin
            if features.ranker_score_range <= 562693437.00000012 then
            begin
                if features.ranker_top_pool_source_kind <= 1.0000000180025095E-35 then
                begin
                    Result := -0.064083712219640709;
                end
                else
                begin
                    Result := -0.019894482612689855;
                end;
            end
            else
            begin
                Result := -0.0088947006552419668;
            end;
        end
        else
        begin
            if features.ranker_top_margin <= 28401906.500000004 then
            begin
                Result := -0.010814991264026056;
            end
            else
            begin
                Result := 0.011609634447360523;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 165682465.00000003 then
        begin
            Result := 0.0099451913841661528;
        end
        else
        begin
            Result := 0.031632143435223893;
        end;
    end;
end;

function long_complete_pool_abstain_tree_28(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_char_lm_gain <= 646.00000000000011 then
    begin
        if features.ranker_top_word_lm_gain <= 198.50000000000003 then
        begin
            if features.ranker_top_char_lm_gain <= 86.000000000000014 then
            begin
                Result := -0.028077931105240178;
            end
            else
            begin
                if features.legacy_top_consensus_support <= 839.50000000000011 then
                begin
                    Result := -0.043351745245187784;
                end
                else
                begin
                    Result := -0.0029062863501029736;
                end;
            end;
        end
        else
        begin
            if features.ranker_second_score <= 197177454.50000003 then
            begin
                Result := 0.013437145340100667;
            end
            else
            begin
                Result := -0.010524991378149386;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_word_lm_bonus <= 535.50000000000011 then
        begin
            Result := 0.001788728962592861;
        end
        else
        begin
            Result := 0.028672498465113161;
        end;
    end;
end;

function long_complete_pool_abstain_tree_29(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 90955716.000000015 then
    begin
        if features.ranker_second_margin <= 82851501.500000015 then
        begin
            Result := -0.014407873727997374;
        end
        else
        begin
            if features.ranker_top_margin <= 27120416.000000004 then
            begin
                if features.ranker_third_score <= -154354806.99999997 then
                begin
                    Result := 0.013226987751982097;
                end
                else
                begin
                    if features.legacy_top_ranker_score <= 366166224.00000006 then
                    begin
                        Result := -0.027286533050175005;
                    end
                    else
                    begin
                        Result := 0.020828138987860657;
                    end;
                end;
            end
            else
            begin
                Result := 0.0078352438453045577;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_chain_rank <= 1.5000000000000002 then
        begin
            Result := 0.019985665394467344;
        end
        else
        begin
            Result := -0.029889355299979978;
        end;
    end;
end;

function long_complete_pool_abstain_tree_30(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 119828629.00000001 then
    begin
        if features.ranker_top_char_lm_score <= -4270.4999999999991 then
        begin
            if features.ranker_second_margin <= 93910420.500000015 then
            begin
                Result := -0.015267002366790825;
            end
            else
            begin
                if features.ranker_top_score <= 14933058.000000002 then
                begin
                    Result := 0.015348316401546821;
                end
                else
                begin
                    if features.input_syllable_count <= 9.5000000000000018 then
                    begin
                        if features.candidate_count <= 23.500000000000004 then
                        begin
                            Result := -0.00027832121279262406;
                        end
                        else
                        begin
                            Result := -0.048151428023599084;
                        end;
                    end
                    else
                    begin
                        Result := 0.0052640790579601875;
                    end;
                end;
            end;
        end
        else
        begin
            Result := 0.0057125594046930775;
        end;
    end
    else
    begin
        Result := 0.0213842307248624;
    end;
end;

function long_complete_pool_abstain_tree_31(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 157333208.00000003 then
    begin
        if features.ranker_top_char_lm_gain <= 86.000000000000014 then
        begin
            if features.input_syllable_count <= 8.5000000000000018 then
            begin
                Result := -0.00078118075434497562;
            end
            else
            begin
                Result := -0.025514666422019518;
            end;
        end
        else
        begin
            if features.legacy_top_word_lm_bonus <= 168.50000000000003 then
            begin
                if features.ranker_top_pool_rank <= 2.5000000000000004 then
                begin
                    Result := -0.022587410508272995;
                end
                else
                begin
                    Result := -0.00074169482216415565;
                end;
            end
            else
            begin
                if features.ranker_second_margin <= 10859014.000000002 then
                begin
                    Result := -0.02244885417290254;
                end
                else
                begin
                    Result := 0.010557906882880134;
                end;
            end;
        end;
    end
    else
    begin
        Result := 0.02628661966059222;
    end;
end;

function long_complete_pool_abstain_tree_32(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 60047865.000000007 then
    begin
        if features.ranker_top_char_lm_gain <= -79.499999999999986 then
        begin
            Result := -0.023223645762512232;
        end
        else
        begin
            if features.ranker_top_consensus_gain <= -229.49999999999997 then
            begin
                Result := -0.02508896903278051;
            end
            else
            begin
                Result := -0.0032572582174724926;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 829127820.00000012 then
        begin
            if features.legacy_top_consensus_support <= 898.50000000000011 then
            begin
                if features.ranker_top_pool_rank <= 4.5000000000000009 then
                begin
                    Result := -0.02546512980266185;
                end
                else
                begin
                    Result := 0.012261078628939461;
                end;
            end
            else
            begin
                Result := 0.010570252173951189;
            end;
        end
        else
        begin
            Result := 0.022815775285087089;
        end;
    end;
end;

function long_complete_pool_abstain_tree_33(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 165682465.00000003 then
    begin
        if features.ranker_top_margin <= 55425471.000000007 then
        begin
            if features.ranker_top_char_lm_gain <= -79.499999999999986 then
            begin
                Result := -0.025002584461267598;
            end
            else
            begin
                Result := -0.0068823231034335058;
            end;
        end
        else
        begin
            if features.legacy_top_ranker_score <= -98128106.499999985 then
            begin
                Result := -0.012972530740267421;
            end
            else
            begin
                if features.ranker_score_range <= 639830883.50000012 then
                begin
                    if features.legacy_top_consensus_support <= 944.50000000000011 then
                    begin
                        Result := -0.062990733415320715;
                    end
                    else
                    begin
                        Result := 0.041551743115304865;
                    end;
                end
                else
                begin
                    Result := 0.014417537576337248;
                end;
            end;
        end;
    end
    else
    begin
        Result := 0.030251282434762189;
    end;
end;

function long_complete_pool_abstain_tree_34(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 161232144.00000003 then
    begin
        if features.ranker_top_margin <= 55425471.000000007 then
        begin
            if features.ranker_top_char_lm_gain <= 863.50000000000011 then
            begin
                if features.ranker_second_margin <= 15655280.000000002 then
                begin
                    Result := -0.033758526182740549;
                end
                else
                begin
                    if features.legacy_top_consensus_support <= 963.50000000000011 then
                    begin
                        Result := -0.013005994782308895;
                    end
                    else
                    begin
                        Result := 0.014202989758628787;
                    end;
                end;
            end
            else
            begin
                Result := 0.00650715153195281;
            end;
        end
        else
        begin
            if features.ranker_second_margin <= 84375795.500000015 then
            begin
                Result := -0.0029069397432339183;
            end
            else
            begin
                Result := 0.016630144622809196;
            end;
        end;
    end
    else
    begin
        Result := 0.029020019138966943;
    end;
end;

function long_complete_pool_abstain_tree_35(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 100773925.00000001 then
    begin
        if features.ranker_top_char_lm_gain <= -79.499999999999986 then
        begin
            Result := -0.018827296057934692;
        end
        else
        begin
            if features.ranker_top_word_lm_bonus <= 430.50000000000006 then
            begin
                Result := -0.0075194394843599377;
            end
            else
            begin
                if features.ranker_second_margin <= 82851501.500000015 then
                begin
                    Result := -0.0042776783728539335;
                end
                else
                begin
                    Result := 0.015722618786982088;
                end;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_consensus_gain <= -57.499999999999993 then
        begin
            Result := 0.022213416515635465;
        end
        else
        begin
            if features.ranker_top_legacy_rank <= 3.5000000000000004 then
            begin
                Result := -0.026463813255164489;
            end
            else
            begin
                Result := 0.025102974237960398;
            end;
        end;
    end;
end;

function long_complete_pool_abstain_tree_36(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_char_lm_gain <= 775.50000000000011 then
    begin
        if features.ranker_top_word_lm_gain <= 71.000000000000014 then
        begin
            Result := -0.014432501839247791;
        end
        else
        begin
            Result := 0.0035701333889042526;
        end;
    end
    else
    begin
        if features.ranker_top_score <= 215160041.00000003 then
        begin
            if features.ranker_third_score <= -15773261.999999998 then
            begin
                Result := 0.0067500231684013891;
            end
            else
            begin
                if features.ranker_top_char_lm_gain <= 1648.5000000000002 then
                begin
                    if features.ranker_second_margin <= 76548907.500000015 then
                    begin
                        Result := -0.0040292860412571973;
                    end
                    else
                    begin
                        Result := -0.097682156373034512;
                    end;
                end
                else
                begin
                    Result := -0.11978180088143578;
                end;
            end;
        end
        else
        begin
            Result := 0.024965786475589492;
        end;
    end;
end;

function long_complete_pool_abstain_tree_37(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 55425471.000000007 then
    begin
        if features.ranker_top_char_lm_gain <= -79.499999999999986 then
        begin
            if features.ranker_top_consensus_support <= 848.50000000000011 then
            begin
                Result := -0.010389153092040939;
            end
            else
            begin
                Result := -0.042398143481453411;
            end;
        end
        else
        begin
            Result := -0.0061547440312379785;
        end;
    end
    else
    begin
        if features.ranker_score_range <= 801739003.00000012 then
        begin
            if features.ranker_top_pool_rank <= 4.5000000000000009 then
            begin
                if features.legacy_top_consensus_support <= 877.50000000000011 then
                begin
                    Result := -0.03544786404315757;
                end
                else
                begin
                    Result := 0.001837289678279942;
                end;
            end
            else
            begin
                Result := 0.014900451955811217;
            end;
        end
        else
        begin
            Result := 0.01923609257217616;
        end;
    end;
end;

function long_complete_pool_abstain_tree_38(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_char_lm_gain <= 634.50000000000011 then
    begin
        if features.ranker_top_word_lm_gain <= 198.50000000000003 then
        begin
            if features.ranker_third_score <= 5005597.5000000009 then
            begin
                if features.ranker_top_legacy_rank <= 7.5000000000000009 then
                begin
                    Result := -0.024122226225111804;
                end
                else
                begin
                    Result := 0.0064672303117290801;
                end;
            end
            else
            begin
                Result := -0.0018942012251488075;
            end;
        end
        else
        begin
            if features.ranker_top_consensus_support <= 781.50000000000011 then
            begin
                Result := -0.0087956357978169353;
            end
            else
            begin
                Result := 0.013761875506301624;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_word_lm_bonus <= 535.50000000000011 then
        begin
            Result := 0.0041384424006290247;
        end
        else
        begin
            Result := 0.024424621645153306;
        end;
    end;
end;

function long_complete_pool_abstain_tree_39(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_char_lm_gain <= 759.50000000000011 then
    begin
        if features.ranker_top_word_lm_gain <= 12.500000000000002 then
        begin
            if features.legacy_top_ranker_score <= -71321005.999999985 then
            begin
                Result := -0.027755003038007306;
            end
            else
            begin
                Result := -0.0089023115726411129;
            end;
        end
        else
        begin
            if features.ranker_top_char_lm_gain <= 108.50000000000001 then
            begin
                Result := -0.0067338910138157728;
            end
            else
            begin
                if features.ranker_top_consensus_support <= 748.50000000000011 then
                begin
                    Result := -0.0069724488770199254;
                end
                else
                begin
                    Result := 0.017061513186457825;
                end;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_word_lm_bonus <= 535.50000000000011 then
        begin
            Result := 0.0037022124679914454;
        end
        else
        begin
            Result := 0.026294493430678256;
        end;
    end;
end;

function long_complete_pool_abstain_tree_40(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 157333208.00000003 then
    begin
        if features.ranker_score_range <= 513131607.00000006 then
        begin
            Result := -0.025035286071295793;
        end
        else
        begin
            if features.ranker_top_char_lm_gain <= 646.00000000000011 then
            begin
                if features.ranker_third_score <= -211604999.49999997 then
                begin
                    Result := 0.013852691829018051;
                end
                else
                begin
                    Result := -0.0083658433381755323;
                end;
            end
            else
            begin
                Result := 0.006887814590387618;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_consensus_support <= 888.50000000000011 then
        begin
            Result := 0.026272981432165048;
        end
        else
        begin
            if features.legacy_top_word_lm_bonus <= 148.50000000000003 then
            begin
                Result := -0.16259507229655046;
            end
            else
            begin
                Result := 0.017193154794433303;
            end;
        end;
    end;
end;

function long_complete_pool_abstain_tree_41(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 90955716.000000015 then
    begin
        if features.legacy_top_consensus_support <= 864.50000000000011 then
        begin
            if features.ranker_second_margin <= 43156798.000000007 then
            begin
                Result := -0.033734918978892019;
            end
            else
            begin
                if features.input_syllable_count <= 13.500000000000002 then
                begin
                    Result := -0.0011757579386873682;
                end
                else
                begin
                    Result := -0.060704854593765206;
                end;
            end;
        end
        else
        begin
            if features.ranker_top_over_legacy_margin <= 419806957.50000006 then
            begin
                Result := -0.0014457286444393353;
            end
            else
            begin
                Result := -0.075260176697843378;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_margin <= 235564541.50000003 then
        begin
            Result := 0.0087429019121695681;
        end
        else
        begin
            Result := 0.034250129748136994;
        end;
    end;
end;

function long_complete_pool_abstain_tree_42(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_word_lm_bonus <= 557.50000000000011 then
    begin
        if features.ranker_score_range <= 562693437.00000012 then
        begin
            if features.ranker_second_margin <= 125693609.00000001 then
            begin
                if features.ranker_top_consensus_support <= 714.50000000000011 then
                begin
                    Result := -0.0022755962768042405;
                end
                else
                begin
                    Result := -0.035758271098917674;
                end;
            end
            else
            begin
                Result := 0.021327641326511455;
            end;
        end
        else
        begin
            Result := -0.0026480017701000003;
        end;
    end
    else
    begin
        if features.ranker_top_over_legacy_margin <= 165178551.50000003 then
        begin
            if features.legacy_top_consensus_support <= 963.50000000000011 then
            begin
                Result := -0.0010741946956196681;
            end
            else
            begin
                Result := 0.024514778445717502;
            end;
        end
        else
        begin
            Result := 0.019251243208688495;
        end;
    end;
end;

function long_complete_pool_abstain_tree_43(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 165682465.00000003 then
    begin
        if features.ranker_second_margin <= 82851501.500000015 then
        begin
            if features.ranker_score_range <= 502818136.00000006 then
            begin
                Result := -0.029477550868670745;
            end
            else
            begin
                Result := -0.0059377879718602571;
            end;
        end
        else
        begin
            if features.ranker_top_margin <= 27120416.000000004 then
            begin
                if features.ranker_third_score <= -179400696.49999997 then
                begin
                    if features.ranker_second_score <= -75290095.499999985 then
                    begin
                        Result := -0.021009735433419705;
                    end
                    else
                    begin
                        Result := 0.049167131211115253;
                    end;
                end
                else
                begin
                    Result := -0.013000014769797136;
                end;
            end
            else
            begin
                Result := 0.011002039544315043;
            end;
        end;
    end
    else
    begin
        Result := 0.025020294747832583;
    end;
end;

function long_complete_pool_abstain_tree_44(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 165682465.00000003 then
    begin
        if features.ranker_top_margin <= 55425471.000000007 then
        begin
            Result := -0.0080021231198398983;
        end
        else
        begin
            if features.legacy_top_ranker_score <= -98128106.499999985 then
            begin
                if features.ranker_top_legacy_rank <= 3.5000000000000004 then
                begin
                    if features.ranker_top_consensus_support <= 846.50000000000011 then
                    begin
                        Result := -0.046303842454106875;
                    end
                    else
                    begin
                        Result := -0.0017257580117218164;
                    end;
                end
                else
                begin
                    Result := 0.0067678984664646868;
                end;
            end
            else
            begin
                if features.ranker_top_char_lm_score <= -2784.9999999999995 then
                begin
                    Result := 0.012199020425692821;
                end
                else
                begin
                    Result := -0.03522862616947179;
                end;
            end;
        end;
    end
    else
    begin
        Result := 0.024806517870594468;
    end;
end;

function long_complete_pool_abstain_tree_45(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 165682465.00000003 then
    begin
        if features.ranker_second_margin <= 82851501.500000015 then
        begin
            if features.ranker_score_range <= 502818136.00000006 then
            begin
                Result := -0.028579117352054439;
            end
            else
            begin
                Result := -0.0054473611275560122;
            end;
        end
        else
        begin
            if features.ranker_top_margin <= 26102198.000000004 then
            begin
                if features.ranker_third_score <= -154354806.99999997 then
                begin
                    if features.ranker_second_margin <= 89840053.500000015 then
                    begin
                        Result := -0.076312959827408822;
                    end
                    else
                    begin
                        Result := 0.022169092352858882;
                    end;
                end
                else
                begin
                    Result := -0.016090441367560448;
                end;
            end
            else
            begin
                Result := 0.010421649665790161;
            end;
        end;
    end
    else
    begin
        Result := 0.023382183145227092;
    end;
end;

function long_complete_pool_abstain_tree_46(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 60047865.000000007 then
    begin
        Result := -0.0071953602624636728;
    end
    else
    begin
        if features.ranker_top_pool_source_kind <= 2.0000000000000004 then
        begin
            if features.ranker_top_char_lm_gain <= 1319.0000000000002 then
            begin
                if features.ranker_top_consensus_support <= 896.50000000000011 then
                begin
                    Result := -0.0097889351957758247;
                end
                else
                begin
                    Result := 0.02548548319154104;
                end;
            end
            else
            begin
                if features.ranker_third_score <= 97291480.500000015 then
                begin
                    if features.legacy_top_char_lm_score <= -7329.4999999999991 then
                    begin
                        Result := -0.026413669761690496;
                    end
                    else
                    begin
                        Result := -0.16737994425689501;
                    end;
                end
                else
                begin
                    Result := 0.021007543291558926;
                end;
            end;
        end
        else
        begin
            Result := 0.014295913100969584;
        end;
    end;
end;

function long_complete_pool_abstain_tree_47(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 165682465.00000003 then
    begin
        if features.ranker_top_char_lm_gain <= 74.500000000000014 then
        begin
            Result := -0.012419310063040073;
        end
        else
        begin
            if features.ranker_top_legacy_rank <= 8.5000000000000018 then
            begin
                if features.chain_count <= 8.5000000000000018 then
                begin
                    if features.ranker_top_word_lm_bonus <= 665.50000000000011 then
                    begin
                        Result := -0.0047816522930185738;
                    end
                    else
                    begin
                        if features.ranker_top_consensus_support <= 741.50000000000011 then
                        begin
                            Result := -0.013304949026454838;
                        end
                        else
                        begin
                            Result := 0.026756995270933951;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.050789410121219514;
                end;
            end
            else
            begin
                Result := 0.01546202049593238;
            end;
        end;
    end
    else
    begin
        Result := 0.022769558872734793;
    end;
end;

function long_complete_pool_abstain_tree_48(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 161232144.00000003 then
    begin
        if features.ranker_top_word_lm_bonus <= 760.50000000000011 then
        begin
            if features.ranker_top_char_lm_score <= -4270.4999999999991 then
            begin
                if features.ranker_top_legacy_rank <= 8.5000000000000018 then
                begin
                    Result := -0.011219389463647176;
                end
                else
                begin
                    if features.legacy_top_char_lm_score <= -7419.4999999999991 then
                    begin
                        Result := -0.044740795625359743;
                    end
                    else
                    begin
                        if features.legacy_top_char_lm_score <= -5773.4999999999991 then
                        begin
                            Result := 0.021445650796928981;
                        end
                        else
                        begin
                            Result := -0.007310650215010101;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := 0.0058667652985328125;
            end;
        end
        else
        begin
            Result := 0.008911426523773032;
        end;
    end
    else
    begin
        Result := 0.020830318009971642;
    end;
end;

function long_complete_pool_abstain_tree_49(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_word_lm_bonus <= 955.00000000000011 then
    begin
        if features.ranker_score_range <= 502818136.00000006 then
        begin
            Result := -0.023564462661931095;
        end
        else
        begin
            if features.ranker_top_legacy_rank <= 4.5000000000000009 then
            begin
                Result := -0.0038032987682902787;
            end
            else
            begin
                if features.ranker_top_chain_rank <= 1.0000000180025095E-35 then
                begin
                    Result := 0.012232913249657593;
                end
                else
                begin
                    if features.legacy_top_consensus_support <= 836.50000000000011 then
                    begin
                        Result := 0.019609639221328398;
                    end
                    else
                    begin
                        if features.ranker_top_consensus_support <= 902.50000000000011 then
                        begin
                            Result := -0.066734289581162398;
                        end
                        else
                        begin
                            Result := 0.031789167924709004;
                        end;
                    end;
                end;
            end;
        end;
    end
    else
    begin
        Result := 0.020387895847697356;
    end;
end;

function long_complete_pool_abstain_tree_50(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_char_lm_gain <= 775.50000000000011 then
    begin
        if features.ranker_top_pair_evidence <= 1084.5000000000002 then
        begin
            if features.ranker_top_legacy_rank <= 9.5000000000000018 then
            begin
                Result := -0.018618991298306468;
            end
            else
            begin
                Result := 0.017623847930072628;
            end;
        end
        else
        begin
            Result := 0.00015217781218596242;
        end;
    end
    else
    begin
        if features.ranker_top_score <= 215160041.00000003 then
        begin
            if features.ranker_third_score <= -12189370.499999998 then
            begin
                Result := 0.0090999503756365903;
            end
            else
            begin
                if features.ranker_second_margin <= 54215299.000000007 then
                begin
                    Result := -0.007036877950401337;
                end
                else
                begin
                    Result := -0.079354487976000018;
                end;
            end;
        end
        else
        begin
            Result := 0.024089579915337628;
        end;
    end;
end;

function long_complete_pool_abstain_tree_51(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 201291687.50000003 then
    begin
        if features.ranker_top_char_lm_gain <= 99.500000000000014 then
        begin
            Result := -0.0099452838606775961;
        end
        else
        begin
            if features.legacy_top_consensus_support <= 861.50000000000011 then
            begin
                if features.ranker_score_range <= 502818136.00000006 then
                begin
                    Result := -0.061192849414495813;
                end
                else
                begin
                    if features.ranker_top_char_lm_gain <= 646.00000000000011 then
                    begin
                        Result := -0.020542489779495719;
                    end
                    else
                    begin
                        Result := 0.005961432065601271;
                    end;
                end;
            end
            else
            begin
                if features.ranker_top_legacy_rank <= 8.5000000000000018 then
                begin
                    Result := 0.002108084139707065;
                end
                else
                begin
                    Result := 0.024000260669618967;
                end;
            end;
        end;
    end
    else
    begin
        Result := 0.026406772166986395;
    end;
end;

function long_complete_pool_abstain_tree_52(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 100773925.00000001 then
    begin
        Result := -0.0036939156340846345;
    end
    else
    begin
        if features.ranker_score_range <= 721141422.50000012 then
        begin
            if features.ranker_top_char_lm_gain <= 108.50000000000001 then
            begin
                Result := -0.071832072402922831;
            end
            else
            begin
                if features.legacy_top_char_lm_score <= -6272.9999999999991 then
                begin
                    Result := 0.021303404452326175;
                end
                else
                begin
                    if features.legacy_top_char_lm_score <= -5939.4999999999991 then
                    begin
                        Result := -0.074253158266443825;
                    end
                    else
                    begin
                        if features.ranker_top_char_lm_gain <= 462.50000000000006 then
                        begin
                            Result := -0.045554748002535173;
                        end
                        else
                        begin
                            Result := 0.042100692695891936;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := 0.018539310464466587;
        end;
    end;
end;

function long_complete_pool_abstain_tree_53(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_score <= 119818113.50000001 then
    begin
        if features.ranker_third_score <= -46762656.999999993 then
        begin
            Result := -0.0023140674213069758;
        end
        else
        begin
            if features.ranker_second_margin <= 8954370.0000000019 then
            begin
                Result := -0.056599474435959939;
            end
            else
            begin
                if features.ranker_second_margin <= 51376855.000000007 then
                begin
                    if features.legacy_top_ranker_score <= 26407099.500000004 then
                    begin
                        Result := -0.022773311714453692;
                    end
                    else
                    begin
                        Result := 0.029764741074063232;
                    end;
                end
                else
                begin
                    Result := -0.048176535500609248;
                end;
            end;
        end;
    end
    else
    begin
        if features.ranker_top_char_lm_gain <= -43.499999999999993 then
        begin
            Result := -0.012651516364874105;
        end
        else
        begin
            Result := 0.0079586174167174239;
        end;
    end;
end;

function long_complete_pool_abstain_tree_54(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 195373867.00000003 then
    begin
        if features.ranker_top_char_lm_gain <= -79.499999999999986 then
        begin
            if features.ranker_top_consensus_gain <= -166.49999999999997 then
            begin
                Result := 0.016004061687788302;
            end
            else
            begin
                Result := -0.022881812459987418;
            end;
        end
        else
        begin
            if features.ranker_top_word_lm_bonus <= 675.50000000000011 then
            begin
                if features.ranker_top_pool_rank <= 8.5000000000000018 then
                begin
                    if features.ranker_score_range <= 569813586.50000012 then
                    begin
                        Result := -0.020507040886583724;
                    end
                    else
                    begin
                        Result := -0.0032876644830498731;
                    end;
                end
                else
                begin
                    Result := 0.013148785305787817;
                end;
            end
            else
            begin
                Result := 0.010627051432955635;
            end;
        end;
    end
    else
    begin
        Result := 0.025803962500399406;
    end;
end;

function long_complete_pool_abstain_tree_55(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 195373867.00000003 then
    begin
        if features.ranker_second_margin <= 82851501.500000015 then
        begin
            if features.legacy_top_ranker_score <= 388842927.50000006 then
            begin
                if features.ranker_top_score <= 405472345.00000006 then
                begin
                    if features.ranker_second_score <= 322423542.00000006 then
                    begin
                        if features.ranker_third_score <= 253206174.00000003 then
                        begin
                            Result := -0.0076800423820031502;
                        end
                        else
                        begin
                            Result := 0.046241483962424078;
                        end;
                    end
                    else
                    begin
                        Result := -0.057916269539962068;
                    end;
                end
                else
                begin
                    Result := 0.037657686909006512;
                end;
            end
            else
            begin
                Result := -0.050457710716554;
            end;
        end
        else
        begin
            Result := 0.0043222587035064075;
        end;
    end
    else
    begin
        Result := 0.025504005601387936;
    end;
end;

function long_complete_pool_abstain_tree_56(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_word_lm_bonus <= 972.50000000000011 then
    begin
        if features.legacy_top_consensus_support <= 863.50000000000011 then
        begin
            if features.ranker_score_range <= 489526695.50000006 then
            begin
                Result := -0.047369162552655601;
            end
            else
            begin
                Result := -0.0080124086053246172;
            end;
        end
        else
        begin
            if features.ranker_top_margin <= 60047865.000000007 then
            begin
                if features.legacy_top_consensus_support <= 879.50000000000011 then
                begin
                    Result := 0.024443423495027605;
                end
                else
                begin
                    Result := -0.0067948288477809558;
                end;
            end
            else
            begin
                if features.ranker_second_margin <= 150972620.00000003 then
                begin
                    Result := 0.0034255291860679792;
                end
                else
                begin
                    Result := 0.026533271189027964;
                end;
            end;
        end;
    end
    else
    begin
        Result := 0.021018892062096499;
    end;
end;

function long_complete_pool_abstain_tree_57(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 161232144.00000003 then
    begin
        if features.ranker_top_char_lm_gain <= 86.000000000000014 then
        begin
            if features.ranker_second_margin <= 224291243.00000003 then
            begin
                if features.ranker_second_margin <= 170757896.00000003 then
                begin
                    Result := -0.012287130133969268;
                end
                else
                begin
                    if features.legacy_top_pair_evidence <= 2674.5000000000005 then
                    begin
                        Result := 0.061109523000960765;
                    end
                    else
                    begin
                        Result := -0.032474377561875822;
                    end;
                end;
            end
            else
            begin
                Result := -0.041101580061087779;
            end;
        end
        else
        begin
            if features.ranker_second_margin <= 2705313.5000000005 then
            begin
                Result := -0.03508202521093777;
            end
            else
            begin
                Result := 0.0016980718645801475;
            end;
        end;
    end
    else
    begin
        Result := 0.019367019809459075;
    end;
end;

function long_complete_pool_abstain_tree_58(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 206862219.50000003 then
    begin
        if features.ranker_second_margin <= 82851501.500000015 then
        begin
            Result := -0.0054775817001745074;
        end
        else
        begin
            if features.ranker_top_margin <= 27120416.000000004 then
            begin
                if features.ranker_third_score <= -179400696.49999997 then
                begin
                    if features.ranker_second_score <= -75290095.499999985 then
                    begin
                        if features.ranker_top_word_lm_gain <= 28.000000000000004 then
                        begin
                            Result := -0.051531295009313284;
                        end
                        else
                        begin
                            Result := 0.030803842832747463;
                        end;
                    end
                    else
                    begin
                        Result := 0.048231393390480888;
                    end;
                end
                else
                begin
                    Result := -0.013445259124877349;
                end;
            end
            else
            begin
                Result := 0.011330760221314217;
            end;
        end;
    end
    else
    begin
        Result := 0.028685150361505488;
    end;
end;

function long_complete_pool_abstain_tree_59(
    const features: TncLongFinalAbstainFeatures): Double;
begin
    if features.ranker_top_margin <= 13025192.000000002 then
    begin
        Result := -0.01415970568707059;
    end
    else
    begin
        if features.ranker_top_margin <= 235564541.50000003 then
        begin
            if features.ranker_top_legacy_rank <= 8.5000000000000018 then
            begin
                if features.ranker_second_margin <= 9924891.0000000019 then
                begin
                    if features.legacy_top_char_lm_score <= -6732.9999999999991 then
                    begin
                        Result := 0.027759985558210177;
                    end
                    else
                    begin
                        Result := -0.029763117793203713;
                    end;
                end
                else
                begin
                    if features.ranker_top_pair_evidence <= 1084.5000000000002 then
                    begin
                        Result := -0.0087014554567949823;
                    end
                    else
                    begin
                        Result := 0.0061853943250153075;
                    end;
                end;
            end
            else
            begin
                Result := 0.013575450729879835;
            end;
        end
        else
        begin
            Result := 0.030424703718819758;
        end;
    end;
end;
function long_complete_pool_abstain_score(
    const features: TncLongFinalAbstainFeatures): Int64;
var
    score: Double;
begin
    score := 0.0;
    score := score + long_complete_pool_abstain_tree_0(features);
    score := score + long_complete_pool_abstain_tree_1(features);
    score := score + long_complete_pool_abstain_tree_2(features);
    score := score + long_complete_pool_abstain_tree_3(features);
    score := score + long_complete_pool_abstain_tree_4(features);
    score := score + long_complete_pool_abstain_tree_5(features);
    score := score + long_complete_pool_abstain_tree_6(features);
    score := score + long_complete_pool_abstain_tree_7(features);
    score := score + long_complete_pool_abstain_tree_8(features);
    score := score + long_complete_pool_abstain_tree_9(features);
    score := score + long_complete_pool_abstain_tree_10(features);
    score := score + long_complete_pool_abstain_tree_11(features);
    score := score + long_complete_pool_abstain_tree_12(features);
    score := score + long_complete_pool_abstain_tree_13(features);
    score := score + long_complete_pool_abstain_tree_14(features);
    score := score + long_complete_pool_abstain_tree_15(features);
    score := score + long_complete_pool_abstain_tree_16(features);
    score := score + long_complete_pool_abstain_tree_17(features);
    score := score + long_complete_pool_abstain_tree_18(features);
    score := score + long_complete_pool_abstain_tree_19(features);
    score := score + long_complete_pool_abstain_tree_20(features);
    score := score + long_complete_pool_abstain_tree_21(features);
    score := score + long_complete_pool_abstain_tree_22(features);
    score := score + long_complete_pool_abstain_tree_23(features);
    score := score + long_complete_pool_abstain_tree_24(features);
    score := score + long_complete_pool_abstain_tree_25(features);
    score := score + long_complete_pool_abstain_tree_26(features);
    score := score + long_complete_pool_abstain_tree_27(features);
    score := score + long_complete_pool_abstain_tree_28(features);
    score := score + long_complete_pool_abstain_tree_29(features);
    score := score + long_complete_pool_abstain_tree_30(features);
    score := score + long_complete_pool_abstain_tree_31(features);
    score := score + long_complete_pool_abstain_tree_32(features);
    score := score + long_complete_pool_abstain_tree_33(features);
    score := score + long_complete_pool_abstain_tree_34(features);
    score := score + long_complete_pool_abstain_tree_35(features);
    score := score + long_complete_pool_abstain_tree_36(features);
    score := score + long_complete_pool_abstain_tree_37(features);
    score := score + long_complete_pool_abstain_tree_38(features);
    score := score + long_complete_pool_abstain_tree_39(features);
    score := score + long_complete_pool_abstain_tree_40(features);
    score := score + long_complete_pool_abstain_tree_41(features);
    score := score + long_complete_pool_abstain_tree_42(features);
    score := score + long_complete_pool_abstain_tree_43(features);
    score := score + long_complete_pool_abstain_tree_44(features);
    score := score + long_complete_pool_abstain_tree_45(features);
    score := score + long_complete_pool_abstain_tree_46(features);
    score := score + long_complete_pool_abstain_tree_47(features);
    score := score + long_complete_pool_abstain_tree_48(features);
    score := score + long_complete_pool_abstain_tree_49(features);
    score := score + long_complete_pool_abstain_tree_50(features);
    score := score + long_complete_pool_abstain_tree_51(features);
    score := score + long_complete_pool_abstain_tree_52(features);
    score := score + long_complete_pool_abstain_tree_53(features);
    score := score + long_complete_pool_abstain_tree_54(features);
    score := score + long_complete_pool_abstain_tree_55(features);
    score := score + long_complete_pool_abstain_tree_56(features);
    score := score + long_complete_pool_abstain_tree_57(features);
    score := score + long_complete_pool_abstain_tree_58(features);
    score := score + long_complete_pool_abstain_tree_59(features);
    Result := Trunc(score * c_long_complete_pool_abstain_score_scale);
end;

function long_complete_pool_abstain_self_test: Boolean;
var
    features: TncLongFinalAbstainFeatures;
begin
    FillChar(features, SizeOf(features), 0);
    if long_complete_pool_abstain_score(features) <>
        c_long_complete_pool_abstain_reference_score then
    begin
        Exit(False);
    end;

    features.candidate_count := -1000000;
    features.complete_count := -1000000;
    features.chain_count := -1000000;
    features.input_syllable_count := -1000000;
    features.has_left_context := False;
    features.ranker_top_score := -1000000;
    features.ranker_second_score := -1000000;
    features.ranker_third_score := -1000000;
    features.ranker_top_margin := -1000000;
    features.ranker_second_margin := -1000000;
    features.ranker_score_range := -1000000;
    features.ranker_top_legacy_rank := -1000000;
    features.ranker_top_chain_rank := -1000000;
    features.ranker_top_complete := False;
    features.ranker_top_user := False;
    features.ranker_top_dictionary := False;
    features.ranker_top_chain := False;
    features.legacy_top_ranker_score := -1000000;
    features.ranker_top_over_legacy_margin := -1000000;
    features.ranker_disagrees := False;
    features.legacy_top_complete := False;
    features.legacy_top_user := False;
    features.legacy_top_dictionary := False;
    features.legacy_top_chain := False;
    features.legacy_top_chain_rank := -1000000;
    features.ranker_top_char_lm_score := -1000000;
    features.legacy_top_char_lm_score := -1000000;
    features.ranker_top_char_lm_gain := -1000000;
    features.ranker_top_path_confidence := -1000000;
    features.legacy_top_path_confidence := -1000000;
    features.ranker_top_path_confidence_gain := -1000000;
    features.ranker_top_query_choice_bonus := -1000000;
    features.legacy_top_query_choice_bonus := -1000000;
    features.ranker_top_pool_source_kind := -1000000;
    features.legacy_top_pool_source_kind := -1000000;
    features.ranker_top_pool_rank := -1000000;
    features.legacy_top_pool_rank := -1000000;
    features.ranker_top_pair_evidence := -1000000;
    features.legacy_top_pair_evidence := -1000000;
    features.ranker_top_word_lm_bonus := -1000000;
    features.legacy_top_word_lm_bonus := -1000000;
    features.ranker_top_word_lm_gain := -1000000;
    features.ranker_top_consensus_support := -1000000;
    features.legacy_top_consensus_support := -1000000;
    features.ranker_top_consensus_gain := -1000000;
    features.ranker_top_proper_name_confidence := -1000000;
    features.legacy_top_proper_name_confidence := -1000000;
    features.ranker_top_local_pairwise_score := -1000000;
    features.legacy_top_local_pairwise_score := -1000000;
    if long_complete_pool_abstain_score(features) <>
        c_long_complete_pool_abstain_reference_score_low then
    begin
        Exit(False);
    end;

    features.candidate_count := 1000000;
    features.complete_count := 1000000;
    features.chain_count := 1000000;
    features.input_syllable_count := 1000000;
    features.has_left_context := True;
    features.ranker_top_score := 1000000;
    features.ranker_second_score := 1000000;
    features.ranker_third_score := 1000000;
    features.ranker_top_margin := 1000000;
    features.ranker_second_margin := 1000000;
    features.ranker_score_range := 1000000;
    features.ranker_top_legacy_rank := 1000000;
    features.ranker_top_chain_rank := 1000000;
    features.ranker_top_complete := True;
    features.ranker_top_user := True;
    features.ranker_top_dictionary := True;
    features.ranker_top_chain := True;
    features.legacy_top_ranker_score := 1000000;
    features.ranker_top_over_legacy_margin := 1000000;
    features.ranker_disagrees := True;
    features.legacy_top_complete := True;
    features.legacy_top_user := True;
    features.legacy_top_dictionary := True;
    features.legacy_top_chain := True;
    features.legacy_top_chain_rank := 1000000;
    features.ranker_top_char_lm_score := 1000000;
    features.legacy_top_char_lm_score := 1000000;
    features.ranker_top_char_lm_gain := 1000000;
    features.ranker_top_path_confidence := 1000000;
    features.legacy_top_path_confidence := 1000000;
    features.ranker_top_path_confidence_gain := 1000000;
    features.ranker_top_query_choice_bonus := 1000000;
    features.legacy_top_query_choice_bonus := 1000000;
    features.ranker_top_pool_source_kind := 1000000;
    features.legacy_top_pool_source_kind := 1000000;
    features.ranker_top_pool_rank := 1000000;
    features.legacy_top_pool_rank := 1000000;
    features.ranker_top_pair_evidence := 1000000;
    features.legacy_top_pair_evidence := 1000000;
    features.ranker_top_word_lm_bonus := 1000000;
    features.legacy_top_word_lm_bonus := 1000000;
    features.ranker_top_word_lm_gain := 1000000;
    features.ranker_top_consensus_support := 1000000;
    features.legacy_top_consensus_support := 1000000;
    features.ranker_top_consensus_gain := 1000000;
    features.ranker_top_proper_name_confidence := 1000000;
    features.legacy_top_proper_name_confidence := 1000000;
    features.ranker_top_local_pairwise_score := 1000000;
    features.legacy_top_local_pairwise_score := 1000000;
    if long_complete_pool_abstain_score(features) <>
        c_long_complete_pool_abstain_reference_score_high then
    begin
        Exit(False);
    end;

    features.candidate_count := 137;
    features.complete_count := -274;
    features.chain_count := 411;
    features.input_syllable_count := -548;
    features.has_left_context := False;
    features.ranker_top_score := -822;
    features.ranker_second_score := 959;
    features.ranker_third_score := -1096;
    features.ranker_top_margin := 1233;
    features.ranker_second_margin := -1370;
    features.ranker_score_range := 1507;
    features.ranker_top_legacy_rank := -1644;
    features.ranker_top_chain_rank := 1781;
    features.ranker_top_complete := True;
    features.ranker_top_user := False;
    features.ranker_top_dictionary := True;
    features.ranker_top_chain := False;
    features.legacy_top_ranker_score := -2466;
    features.ranker_top_over_legacy_margin := 2603;
    features.ranker_disagrees := True;
    features.legacy_top_complete := False;
    features.legacy_top_user := True;
    features.legacy_top_dictionary := False;
    features.legacy_top_chain := True;
    features.legacy_top_chain_rank := 3425;
    features.ranker_top_char_lm_score := -3562;
    features.legacy_top_char_lm_score := 3699;
    features.ranker_top_char_lm_gain := -3836;
    features.ranker_top_path_confidence := 3973;
    features.legacy_top_path_confidence := -4110;
    features.ranker_top_path_confidence_gain := 4247;
    features.ranker_top_query_choice_bonus := -4384;
    features.legacy_top_query_choice_bonus := 4521;
    features.ranker_top_pool_source_kind := -4658;
    features.legacy_top_pool_source_kind := 4795;
    features.ranker_top_pool_rank := -4932;
    features.legacy_top_pool_rank := 5069;
    features.ranker_top_pair_evidence := -5206;
    features.legacy_top_pair_evidence := 5343;
    features.ranker_top_word_lm_bonus := -5480;
    features.legacy_top_word_lm_bonus := 5617;
    features.ranker_top_word_lm_gain := -5754;
    features.ranker_top_consensus_support := 5891;
    features.legacy_top_consensus_support := -6028;
    features.ranker_top_consensus_gain := 6165;
    features.ranker_top_proper_name_confidence := -6302;
    features.legacy_top_proper_name_confidence := 6439;
    features.ranker_top_local_pairwise_score := -6576;
    features.legacy_top_local_pairwise_score := 6713;
    Result := long_complete_pool_abstain_score(features) =
        c_long_complete_pool_abstain_reference_score_mixed;
end;

end.
