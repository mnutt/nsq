#!/bin/bash
readonly messageSize="${1:-200}"
readonly batchSize="${2:-200}"
readonly memQueueSize="${3:-1000000}"
readonly dataPath="${4:-}"
set -e
set -u

echo "# using --mem-queue-size=$memQueueSize --data-path=$dataPath --size=$messageSize --batch-size=$batchSize"
echo "# compiling/running nsqd"
pushd apps/nsqd >/dev/null
# go build
rm -f *.dat
./nsqd --version
taskset -c 0 ./nsqd --sync-every=2500 --sync-timeout=2s --snappy=true --data-path=$dataPath --max-body-size=5123840 --max-bytes-per-file=104857600 --max-msg-size=1024768 --max-msg-timeout=15m0s --max-rdy-count=2500 --mem-queue-size=10000 --msg-timeout=15m0s >/dev/null 2>&1 &
nsqd_pid=$!
popd >/dev/null

cleanup() {
    kill -9 $nsqd_pid
    rm -f nsqd/*.dat
}
trap cleanup INT TERM EXIT

sleep 0.3
echo "# creating topic/channel"
curl --silent 'http://127.0.0.1:4151/create_topic?topic=sub_bench' >/dev/null 2>&1
curl --silent 'http://127.0.0.1:4151/create_channel?topic=sub_bench&channel=ch' >/dev/null 2>&1
curl --silent 'http://127.0.0.1:4151/create_channel?topic=sub_bench&channel=ch2' >/dev/null 2>&1
curl --silent 'http://127.0.0.1:4151/create_channel?topic=sub_bench&channel=ch3' >/dev/null 2>&1
curl --silent 'http://127.0.0.1:4151/create_channel?topic=sub_bench&channel=ch4' >/dev/null 2>&1
#curl --silent 'http://127.0.0.1:4151/create_channel?topic=sub_bench&channel=ch5' >/dev/null 2>&1
#curl --silent 'http://127.0.0.1:4151/create_channel?topic=sub_bench&channel=ch6' >/dev/null 2>&1
#curl --silent 'http://127.0.0.1:4151/create_channel?topic=sub_bench&channel=ch7' >/dev/null 2>&1
#curl --silent 'http://127.0.0.1:4151/create_channel?topic=sub_bench&channel=ch8' >/dev/null 2>&1

echo "# compiling bench_reader/bench_writer"
pushd bench >/dev/null
for app in bench_reader bench_writer; do
    pushd $app >/dev/null
    go build
    popd >/dev/null
done
popd >/dev/null

echo -n "PUB: "
taskset -c 1 bench/bench_writer/bench_writer --size=$messageSize --batch-size=$batchSize 2>&1

#curl -s -o cpu.pprof http://127.0.0.1:4151/debug/pprof/profile &
#pprof_pid=$!

echo -n "SUB: "
taskset -c 1 bench/bench_reader/bench_reader --size=$messageSize --channel=ch2 2>&1 &
taskset -c 1 bench/bench_reader/bench_reader --size=$messageSize --channel=ch3 2>&1 &
taskset -c 1 bench/bench_reader/bench_reader --size=$messageSize --channel=ch4 2>&1 &
#taskset -c 1 bench/bench_reader/bench_reader --size=$messageSize --channel=ch5 2>&1 &
#taskset -c 1 bench/bench_reader/bench_reader --size=$messageSize --channel=ch6 2>&1 &
#taskset -c 1 bench/bench_reader/bench_reader --size=$messageSize --channel=ch7 2>&1 &
#taskset -c 1 bench/bench_reader/bench_reader --size=$messageSize --channel=ch8 2>&1 &
taskset -c 1 bench/bench_reader/bench_reader --size=$messageSize --channel=ch 2>&1

#echo "waiting for pprof..."
#wait $pprof_pid