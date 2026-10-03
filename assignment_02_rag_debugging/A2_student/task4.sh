rm -rf rtl/datapath.sv



python agent/run_debug_agent.py --module datapath --arm rag --provider tamu --log-file logs/ablation_rag_1.json
mkdir -p ablation_experiment/rag
mv logs/ablation_rag_1.json ablation_experiment/rag/ablation_rag_1.json
mv rtl/datapath.sv ablation_experiment/rag/datapath_1.sv

python agent/run_debug_agent.py --module datapath --arm rag --provider tamu --log-file logs/ablation_rag_2.json
mkdir -p ablation_experiment/rag
mv logs/ablation_rag_2.json ablation_experiment/rag/ablation_rag_2.json
mv rtl/datapath.sv ablation_experiment/rag/datapath_2.sv



python agent/run_debug_agent.py --module datapath --arm rag --provider tamu --log-file logs/ablation_rag_3.json
mkdir -p ablation_experiment/rag
mv logs/ablation_rag_3.json ablation_experiment/rag/ablation_rag_3.json
mv rtl/datapath.sv ablation_experiment/rag/datapath_3.sv




python agent/run_debug_agent.py --module datapath --arm rag_feedback --provider tamu --log-file logs/ablation_rag_1.json
mkdir -p ablation_experiment/rag_feedback
mv logs/ablation_rag_1.json ablation_experiment/rag_feedback/ablation_rag_1.json
mv rtl/datapath.sv ablation_experiment/rag_feedback/datapath_1.sv

python agent/run_debug_agent.py --module datapath --arm rag_feedback --provider tamu --log-file logs/ablation_rag_2.json
mkdir -p ablation_experiment/rag_feedback
mv logs/ablation_rag_2.json ablation_experiment/rag_feedback/ablation_rag_2.json
mv rtl/datapath.sv ablation_experiment/rag_feedback/datapath_2.sv


python agent/run_debug_agent.py --module datapath --arm rag_feedback --provider tamu --log-file logs/ablation_rag_3.json
mkdir -p ablation_experiment/rag_feedback
mv logs/ablation_rag_3.json ablation_experiment/rag_feedback/ablation_rag_3.json
mv rtl/datapath.sv ablation_experiment/rag_feedback/datapath_3.sv
