#!/bin/sh

ensure_file () {
  [ -f "$1" ]
  echo "File $1 exists"
}

BUCKET="abcd"

# Expects content to be in a folder ./content
# Expects ./content/setup_manifest.csv to contain a list of initial files
# Expects all of those files to exist at ./content/$file
# Expects ./content/test_manifest to contain a list of comma-separated pairs of input and output files
# Expects all of those files to exist at ./content/$file

CONTENT="./__bw_files"
SETUP_MANIFEST="${CONTENT}/setup_manifest.csv"
TEST_MANIFEST="${CONTENT}/test_manifest.csv"

echo "Verifying manifest integrity"

ensure_file "${SETUP_MANIFEST}"

cat ${SETUP_MANIFEST} | while read setup_file
do
  ensure_file "${CONTENT}/${setup_file}"
done

ensure_file "${TEST_MANIFEST}"

cat ${TEST_MANIFEST} | while IFS=',' read input_file output_file
do
  ensure_file "${CONTENT}/${input_file}"
  ensure_file "${CONTENT}/${output_file}"
done

# Prepares the setup script

function upload_setup_files () {
  #cat ${SETUP_MANIFEST} | awk "{print \"${CONTENT}/\" \$0 }" | xargs -n 1 ./upload_file.sh ${BUCKET} 
  cat ${SETUP_MANIFEST} | while read setup_file
  do
    URL=$(./upload_file.sh ${BUCKET} ${CONTENT}/${setup_file})
    echo "wget -P '${CONTENT}' -O '${setup_file}' '${URL}'"
  done
}

SETUP_SCRIPT="setup.sh"

cat >${SETUP_SCRIPT} <<EOF
#!/bin/sh
$(upload_setup_files)
EOF

# Prepares the test script

function upload_test_files () {
  cat ${TEST_MANIFEST} | while IFS=',' read input_file output_file
  do
    INPUT_URL=$(./upload_file.sh ${BUCKET} ${CONTENT}/${input_file})
    echo "wget -P '${CONTENT}' -O '${input_file}' '${INPUT_URL}'"
    OUTPUT_URL=$(./upload_file.sh ${BUCKET} ${CONTENT}/${output_file})
    echo "wget -P '${CONTENT}' -O '${output_file}' '${OUTPUT_URL}'"
    echo "echo ===== RUNNING TEST ====="
    echo "./run.sh '${CONTENT}/${input_file}' | diff - '${CONTENT}/${output_file}'"
    echo "echo ===== TEST FINISHED ====="
    echo
  done
}

TEST_SCRIPT="test.sh"

cat >${TEST_SCRIPT} <<EOF
#!/bin/sh
$(upload_test_files)
EOF

