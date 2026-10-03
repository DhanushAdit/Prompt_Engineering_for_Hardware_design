"""Summarize archived Task 4 runs without counting duplicate logs/ copies."""
import csv
import hashlib
import json
from pathlib import Path
from statistics import mean


def main():
    output = Path(__file__).resolve().parent
    root = output.parents[1]
    runs = []
    for path in sorted((root / 'ablation_experiment').rglob('*.json')):
        record = json.loads(path.read_text())
        if record.get('module') != 'datapath' or 'iterations' not in record:
            continue
        iterations = record['iterations']
        passing = [i['iteration'] for i in iterations if i['status'] == 'pass']
        assert bool(passing) == (record['final_status'] == 'pass'), path
        assert [i['iteration'] for i in iterations] == list(range(len(iterations))), path
        assert len(iterations) <= 6, path
        runs.append({
            'part': 'B' if record.get('seed_rtl') else 'A',
            'arm': record['arm'],
            'source': str(path.relative_to(root)),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'provider': record['provider'], 'model': record['model'],
            'seed_rtl': record.get('seed_rtl'),
            'final_status': record['final_status'],
            'tested_candidates': len(iterations),
            'repairs_attempted': len(iterations) - 1,
            'successful_repairs': min(passing) if passing else None,
            'trace': ' -> '.join(f"{i['iteration']}:{i['status']}({i['returncode']})" for i in iterations),
        })
    metrics = []
    for part, arms in [('A', ['baseline', 'rag', 'rag_feedback']), ('B', ['rag', 'rag_feedback'])]:
        for arm in arms:
            group = [r for r in runs if r['part'] == part and r['arm'] == arm]
            successes = [r['successful_repairs'] for r in group if r['successful_repairs'] is not None]
            metrics.append({
                'part': part, 'arm': arm, 'expected_runs': 3,
                'observed_runs': len(group), 'successful_runs': len(successes),
                'failed_runs': len(group) - len(successes),
                'pass_rate_percent': 100 * len(successes) / len(group) if group else None,
                'mean_repairs_success_only': mean(successes) if successes else None,
                'min_repairs_success_only': min(successes) if successes else None,
                'max_repairs_success_only': max(successes) if successes else None,
                'evidence_status': 'complete' if len(group) == 3 else 'incomplete',
            })
    for filename, rows in [('ablation_run_metrics.csv', runs), ('ablation_summary.csv', metrics)]:
        with (output / filename).open('w', newline='') as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
    (output / 'ablation_metrics.json').write_text(json.dumps({'runs': runs, 'summary': metrics}, indent=2) + '\n')
    print(json.dumps(metrics, indent=2))


if __name__ == '__main__':
    main()
