#!/bin/bash
CHANNEL_NAME="$1"
: ${CHANNEL_NAME:="hashvegas"}
DELAY="$2"
: ${DELAY:="3"}
MAX_RETRY="$3"
: ${MAX_RETRY:="10"}
VERBOSE="$4"
: ${VERBOSE:="false"}
CHAINCODE_NAME="$5"
: ${CHAINCODE_NAME:="hashvegas-dealer"}
CHAINCODE_VERSION="$6"
: ${CHAINCODE_VERSION:="v1"}
CHAINCODE_SEQUENCE="$7"
: ${CHAINCODE_SEQUENCE:="1"}
CHAINCODE_INIT_REQUIRED="--init-required"
CHAINCODE_END_POLICY="$8"
: ${CHAINCODE_END_POLICY:=""}
CHAINCODE_COLL_CONFIG="$9"
: ${CHAINCODE_COLL_CONFIG:=""}

export TEST_NETWORK_HOME="/Users/daeyongkim/fabric-network-test/mdl-fabric-testnet/Nch-Norg"
export BIN_DIR="${TEST_NETWORK_HOME}/bin"
# CA-BIN
export CA_BIN_DIR="${TEST_NETWORK_HOME}/ca-bin"
export LOG_DIR="${TEST_NETWORK_HOME}/log"
export FABRIC_CFG_PATH=${TEST_NETWORK_HOME}/config

COMPOSE_FILE_CA=docker/docker-compose-ca.yaml
COMPOSE_FILE_BASE=docker/docker-compose-test-net.yaml
COMPOSE_FILE_COUCH=docker/docker-compose-couch.yaml

function createOrg1() {
   echo "Enrolling the CA admin"

   mkdir -p ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/

   export FABRIC_CA_CLIENT_HOME=${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/

   Org1_address="fabric-ca/org1/tls-cert.pem"
   Org1_CACert="fabric-ca/org1/ca-cert.pem"

   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://admin:adminpw@localhost:7054 --caname ca.org1.example.com --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null

   echo 'NodeOUs:
     Enable: true
     ClientOUIdentifier:
         Certificate: cacerts/localhost-7054-ca-org1-example-com.pem
         OrganizationalUnitIdentifier: client
     PeerOUIdentifier:
         Certificate: cacerts/localhost-7054-ca-org1-example-com.pem
         OrganizationalUnitIdentifier: peer
     AdminOUIdentifier:
         Certificate: cacerts/localhost-7054-ca-org1-example-com.pem
         OrganizationalUnitIdentifier: admin
     OrdererOUIdentifier:
         Certificate: cacerts/localhost-7054-ca-org1-example-com.pem
         OrganizationalUnitIdentifier: orderer' >${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/msp/config.yaml

   # Copy org1's CA cert to org1's /msp/tlscacerts directory (for use in the channel MSP definition)
   mkdir -p "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/msp/tlscacerts"
   cp "${TEST_NETWORK_HOME}/organizations/${Org1_CACert}" "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/msp/tlscacerts/ca.crt"

   # Copy org1's CA cert to org1's /tlsca directory (for use by clients)
   mkdir -p "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/tlsca"
   cp "${TEST_NETWORK_HOME}/organizations/${Org1_CACert}" "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem"

   # Copy org1's CA cert to org1's /ca directory (for use by clients)
   mkdir -p "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/ca"
   cp "${TEST_NETWORK_HOME}/organizations/${Org1_CACert}" "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/ca/ca.org1.example.com-cert.pem"

   echo "Registering peer0"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org1.example.com --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null

   echo "Generating the peer0 msp"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://peer0:peer0pw@localhost:7054 --caname ca.org1.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null
   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp/config.yaml

   echo "Generating the peer0-tls certificates"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://peer0:peer0pw@localhost:7054 --caname ca.org1.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls --enrollment.profile tls --csr.hosts peer0.org1.example.com --csr.hosts localhost --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null

   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/tlscacerts/* ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/signcerts/* ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.crt
   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/keystore/* ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.key


   echo "Registering user1"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org1.example.com --id.name org1user1 --id.secret org1user1pw --id.type client --id.attrs '"hf.Registrar.Roles=client"' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null
   echo "Registering user2"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org1.example.com --id.name org1user2 --id.secret org1user2pw --id.type client --id.attrs '"hf.Registrar.Roles=client"' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null
   echo "Registering user3"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org1.example.com --id.name org1user3 --id.secret org1user3pw --id.type client --id.attrs '"hf.Registrar.Roles=client"' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null

   echo "Registering the org admin"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org1.example.com --id.name org1admin --id.secret org1adminpw --id.type admin --id.attrs '"hf.Registrar.Roles=admin",hf.Revoker=true' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null

   ## create client
   echo "Generating the user1 msp"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org1user1:org1user1pw@localhost:7054 --caname ca.org1.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/users/Org1User1@org1.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null

   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/users/Org1User1@org1.example.com/msp/config.yaml

   echo "Generating the user2 msp"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org1user2:org1user2pw@localhost:7054 --caname ca.org1.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/users/Org1User2@org1.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null

   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/users/Org1User2@org1.example.com/msp/config.yaml

   echo "Generating the user3 msp"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org1user3:org1user3pw@localhost:7054 --caname ca.org1.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/users/Org1User3@org1.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null

   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/users/Org1User3@org1.example.com/msp/config.yaml

   echo "Generating the org admin msp"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org1admin:org1adminpw@localhost:7054 --caname ca.org1.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org1_CACert}
   { set +x; } 2>/dev/null

   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/config.yaml

   keystore_dir=${TEST_NETWORK_HOME}/organizations/peerOrganizations/org1.example.com/users/Org1User1@org1.example.com/msp/keystore
   for file in ${keystore_dir}/*; do
       mv "$file" "${keystore_dir}/priv_sk"
   done
 }

function createOrg2() {
  echo "Enrolling the CA admin"

     mkdir -p ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/

     export FABRIC_CA_CLIENT_HOME=${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/

     Org2_address="fabric-ca/org2/tls-cert.pem"
     Org2_CACert="fabric-ca/org2/ca-cert.pem"

     set -x
     ${CA_BIN_DIR}/fabric-ca-client enroll -u https://admin:adminpw@localhost:8054 --caname ca.org2.example.com --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
     { set +x; } 2>/dev/null

     echo 'NodeOUs:
       Enable: true
       ClientOUIdentifier:
           Certificate: cacerts/localhost-8054-ca-org2-example-com.pem
           OrganizationalUnitIdentifier: client
       PeerOUIdentifier:
           Certificate: cacerts/localhost-8054-ca-org2-example-com.pem
           OrganizationalUnitIdentifier: peer
       AdminOUIdentifier:
           Certificate: cacerts/localhost-8054-ca-org2-example-com.pem
           OrganizationalUnitIdentifier: admin
       OrdererOUIdentifier:
           Certificate: cacerts/localhost-8054-ca-org2-example-com.pem
           OrganizationalUnitIdentifier: orderer' >${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/msp/config.yaml

     # Copy org2's CA cert to org2's /msp/tlscacerts directory (for use in the channel MSP definition)
     mkdir -p "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/msp/tlscacerts"
     cp "${TEST_NETWORK_HOME}/organizations/${Org2_CACert}" "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/msp/tlscacerts/ca.crt"

     # Copy org2's CA cert to org2's /tlsca directory (for use by clients)
     mkdir -p "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/tlsca"
     cp "${TEST_NETWORK_HOME}/organizations/${Org2_CACert}" "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem"

     # Copy org2's CA cert to org2's /ca directory (for use by clients)
     mkdir -p "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/ca"
     cp "${TEST_NETWORK_HOME}/organizations/${Org2_CACert}" "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/ca/ca.org2.example.com-cert.pem"

    echo "Registering peer0"
    set -x
    ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org2.example.com --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
    { set +x; } 2>/dev/null

    echo "Generating the peer0 msp"
    set -x
    ${CA_BIN_DIR}/fabric-ca-client enroll -u https://peer0:peer0pw@localhost:8054 --caname ca.org2.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
    { set +x; } 2>/dev/null
    cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/msp/config.yaml

    echo "Generating the peer0-tls certificates"
    set -x
    ${CA_BIN_DIR}/fabric-ca-client enroll -u https://peer0:peer0pw@localhost:8054 --caname ca.org2.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls --enrollment.profile tls --csr.hosts peer0.org2.example.com --csr.hosts localhost --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
    { set +x; } 2>/dev/null

    cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/tlscacerts/* ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/signcerts/* ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.crt
    cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/keystore/* ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.key

     echo "Registering user1"
     set -x
     ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org2.example.com --id.name org2user1 --id.secret org2user1pw --id.type client --id.attrs '"hf.Registrar.Roles=client"' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
     { set +x; } 2>/dev/null
     echo "Registering user2"
     set -x
     ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org2.example.com --id.name org2user2 --id.secret org2user2pw --id.type client --id.attrs '"hf.Registrar.Roles=client"' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
     { set +x; } 2>/dev/null
     echo "Registering user3"
     set -x
     ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org2.example.com --id.name org2user3 --id.secret org2user3pw --id.type client --id.attrs '"hf.Registrar.Roles=client"' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
     { set +x; } 2>/dev/null

     echo "Registering the org admin"
     set -x
     ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org2.example.com --id.name org2admin --id.secret org2adminpw --id.type admin --id.attrs '"hf.Registrar.Roles=admin",hf.Revoker=true' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
     { set +x; } 2>/dev/null

     ## create client
     echo "Generating the user1 msp"
     set -x
     ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org2user1:org2user1pw@localhost:8054 --caname ca.org2.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/users/Org2User1@org2.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
     { set +x; } 2>/dev/null

     cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/users/Org2User1@org2.example.com/msp/config.yaml

     echo "Generating the user2 msp"
     set -x
     ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org2user2:org2user2pw@localhost:8054 --caname ca.org2.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/users/Org2User2@org2.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
     { set +x; } 2>/dev/null

     cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/users/Org2User2@org2.example.com/msp/config.yaml

     echo "Generating the user3 msp"
     set -x
     ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org2user3:org2user3pw@localhost:8054 --caname ca.org2.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/users/Org2User3@org2.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
     { set +x; } 2>/dev/null

     cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/users/Org2User3@org2.example.com/msp/config.yaml

     echo "Generating the org admin msp"
     set -x
     ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org2admin:org2adminpw@localhost:8054 --caname ca.org2.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org2_CACert}
     { set +x; } 2>/dev/null

     cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp/config.yaml

     keystore_dir=${TEST_NETWORK_HOME}/organizations/peerOrganizations/org2.example.com/users/Org2User1@org2.example.com/msp/keystore
     for file in ${keystore_dir}/*; do
         mv "$file" "${keystore_dir}/priv_sk"
     done
 }

function createOrg3() {
   echo "Enrolling the CA admin"

   mkdir -p ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/

   export FABRIC_CA_CLIENT_HOME=${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/

   Org3_address="fabric-ca/org3/tls-cert.pem"
   Org3_CACert="fabric-ca/org3/ca-cert.pem"

   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://admin:adminpw@localhost:6054 --caname ca.org3.example.com --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null

   echo 'NodeOUs:
     Enable: true
     ClientOUIdentifier:
         Certificate: cacerts/localhost-6054-ca-org3-example-com.pem
         OrganizationalUnitIdentifier: client
     PeerOUIdentifier:
         Certificate: cacerts/localhost-6054-ca-org3-example-com.pem
         OrganizationalUnitIdentifier: peer
     AdminOUIdentifier:
         Certificate: cacerts/localhost-6054-ca-org3-example-com.pem
         OrganizationalUnitIdentifier: admin
     OrdererOUIdentifier:
         Certificate: cacerts/localhost-6054-ca-org3-example-com.pem
         OrganizationalUnitIdentifier: orderer' >${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/msp/config.yaml

   # Copy org3's CA cert to org3's /msp/tlscacerts directory (for use in the channel MSP definition)
   mkdir -p "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/msp/tlscacerts"
   cp "${TEST_NETWORK_HOME}/organizations/${Org3_CACert}" "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/msp/tlscacerts/ca.crt"

   # Copy org3's CA cert to org3's /tlsca directory (for use by clients)
   mkdir -p "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/tlsca"
   cp "${TEST_NETWORK_HOME}/organizations/${Org3_CACert}" "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/tlsca/tlsca.org3.example.com-cert.pem"

   # Copy org3's CA cert to org3's /ca directory (for use by clients)
   mkdir -p "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/ca"
   cp "${TEST_NETWORK_HOME}/organizations/${Org3_CACert}" "${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/ca/ca.org3.example.com-cert.pem"

   echo "Registering peer0"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org3.example.com --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null

   echo "Generating the peer0 msp"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://peer0:peer0pw@localhost:6054 --caname ca.org3.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null
   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/msp/config.yaml

   echo "Generating the peer0-tls certificates"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://peer0:peer0pw@localhost:6054 --caname ca.org3.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls --enrollment.profile tls --csr.hosts peer0.org3.example.com --csr.hosts localhost --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null

   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/tlscacerts/* ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/signcerts/* ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.crt
   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/keystore/* ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.key


   echo "Registering user1"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org3.example.com --id.name org3user1 --id.secret org3user1pw --id.type client --id.attrs '"hf.Registrar.Roles=client"' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null
   echo "Registering user2"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org3.example.com --id.name org3user2 --id.secret org3user2pw --id.type client --id.attrs '"hf.Registrar.Roles=client"' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null
   echo "Registering user3"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org3.example.com --id.name org3user3 --id.secret org3user3pw --id.type client --id.attrs '"hf.Registrar.Roles=client"' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null

   echo "Registering the org admin"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client register --caname ca.org3.example.com --id.name org3admin --id.secret org3adminpw --id.type admin --id.attrs '"hf.Registrar.Roles=admin",hf.Revoker=true' --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null

   ## create client
   echo "Generating the user1 msp"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org3user1:org3user1pw@localhost:6054 --caname ca.org3.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/users/Org3User1@org3.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null

   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/users/Org3User1@org3.example.com/msp/config.yaml

   echo "Generating the user2 msp"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org3user2:org3user2pw@localhost:6054 --caname ca.org3.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/users/Org3User2@org3.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null

   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/users/Org3User2@org3.example.com/msp/config.yaml

   echo "Generating the user3 msp"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org3user3:org3user3pw@localhost:6054 --caname ca.org3.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/users/Org3User3@org3.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null

   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/users/Org3User3@org3.example.com/msp/config.yaml

   echo "Generating the org admin msp"
   set -x
   ${CA_BIN_DIR}/fabric-ca-client enroll -u https://org3admin:org3adminpw@localhost:6054 --caname ca.org3.example.com -M ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Org3_CACert}
   { set +x; } 2>/dev/null

   cp ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp/config.yaml

   keystore_dir=${TEST_NETWORK_HOME}/organizations/peerOrganizations/org3.example.com/users/Org3User1@org31.example.com/msp/keystore
   for file in ${keystore_dir}/*; do
       mv "$file" "${keystore_dir}/priv_sk"
   done
 }

function createOrderer() {
  echo "Enrolling the CA admin"

  mkdir -p ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com

  export FABRIC_CA_CLIENT_HOME=${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com

  Orderer_address="fabric-ca/ordererOrg/tls-cert.pem"

  set -x
  ${CA_BIN_DIR}/fabric-ca-client enroll -u https://admin:adminpw@localhost:9054 --caname ca.orderer.example.com --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Orderer_address}
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer-example-com.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer-example-com.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer-example-com.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer-example-com.pem
    OrganizationalUnitIdentifier: orderer' >${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/msp/config.yaml

  echo "Registering orderer"
  set -x
  ${CA_BIN_DIR}/fabric-ca-client register --caname ca.orderer.example.com --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Orderer_address}
  { set +x; } 2>/dev/null

  echo "Registering the orderer admin"
  set -x
  ${CA_BIN_DIR}/fabric-ca-client register --caname ca.orderer.example.com --id.name ordererAdmin --id.secret ordererAdminpw --id.type admin --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Orderer_address}
  { set +x; } 2>/dev/null

  echo "Generating the orderer msp"
  set -x
  ${CA_BIN_DIR}/fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca.orderer.example.com -M ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Orderer_address}
  { set +x; } 2>/dev/null

  cp ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/config.yaml

  echo "Generating the orderer-tls certificates"
  set -x
  ${CA_BIN_DIR}/fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca.orderer.example.com -M ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls --enrollment.profile tls --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Orderer_address}
  { set +x; } 2>/dev/null

  cp ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/* ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
  cp ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/signcerts/* ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
  cp ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/keystore/* ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

  mkdir -p ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts
  cp ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/* ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

  mkdir -p ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/msp/tlscacerts
  cp ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/* ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem

  echo "Generating the admin msp"
  set -x
  ${CA_BIN_DIR}/fabric-ca-client enroll -u https://ordererAdmin:ordererAdminpw@localhost:9054 --caname ca.orderer.example.com -M ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp --tls.certfiles ${TEST_NETWORK_HOME}/organizations/${Orderer_address}
  { set +x; } 2>/dev/null

  cp ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/msp/config.yaml ${TEST_NETWORK_HOME}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp/config.yaml
}

function main() {

  while :; do
    if [ ! -f "organizations/fabric-ca/org1/tls-cert.pem" ]; then
      sleep 1
    else
      break
    fi
  done
  createOrg1

  while :; do
    if [ ! -f "organizations/fabric-ca/org2/tls-cert.pem" ]; then
      sleep 1
    else

      break
    fi
  done
  createOrg2

  while :; do
    if [ ! -f "organizations/fabric-ca/org3/tls-cert.pem" ]; then
      sleep 1
    else

      break
    fi
  done
  createOrg3

  while :; do
    if [ ! -f "organizations/fabric-ca/ordererOrg/tls-cert.pem" ]; then
      echo no
      sleep 1
    else
      break
    fi
  done
  createOrderer
  ./ccp-generate.sh

  echo "finished to registerEnroll(create org1, org2, orderer)"
  sleep 1

}

main
