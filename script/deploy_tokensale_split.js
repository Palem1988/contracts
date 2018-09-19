const cli = require('readline-sync');
const Connection = require('./eth_connection');
const tokensale = require('./contracts/tokensale_split');

const environment = 'foundation'; // ropsten/foundation, change to foundation to deploy to real
var mnemonics = cli.question('Enter your mnemonics or pkey for '+environment+' account:');
var connection = new Connection(mnemonics, environment);


function deploy_contract(connection, tokensale, gasprice, callback){

    var _startFundingTime = new Date('Jul 17 2018 21:00:00 GMT+0300 (MSK)').getTime()/1000; /* var of type uint256 here */ ;
    var _endFundingTime = new Date('Dec 31 2018 23:59:59 GMT+0300 (MSK)').getTime()/1000;/* var of type uint256 here */ ;
    var _tokenCap = '2500000000000000000000000000';/* var of type uint256 here */ ;
    var _vaultAddress = connection.config.vault;/* var of type address here */ ;
    var _tokenAddress = connection.config.token;/* var of type address here */ ;
    var _transfersAllowed = false; /* var of type bool here */ ;
    var _exchangeRate = 47256;/* var of type uint256 here */ ;

    var browser_izx_crowdsale_tokensaleall_sol_tokensaleContract = connection.web3.eth.contract(tokensale.abi);

    console.log('Deploying contract with gas: '+tokensale.gas);

    browser_izx_crowdsale_tokensaleall_sol_tokensaleContract.new(
        _startFundingTime,
        _endFundingTime,
        _tokenCap,
        _vaultAddress,
        _tokenAddress,
        _transfersAllowed,
        _exchangeRate,
        {
            from: connection.address,
            data: tokensale.bytecode,
            gas: tokensale.gas,
            gasPrice: connection.web3.toWei(gasprice, 'gwei')
        }, function (e, contract){
            if(e){
                console.log(e);
            }
            callback(contract);
        })


}

connection.web3.eth.getBalance(connection.address, function(error,result){
        if(error){
            console.log(error);
            process.exit(1);
        }else{
            console.log( "Creator address is: "+connection.address);
            console.log( "Creator balance is: "+connection.web3.fromWei(result.toNumber()) + 'ETH' );
            console.log( 'Vault address '+ connection.config.vault);
            console.log( 'Token address '+ connection.config.token );
            var gasprice = cli.question('Enter gas price in gwei:');
            
            var yesno = cli.question('Enter Yes! to continue in '+environment+ ' with these parameters: ');
            if(yesno!='Yes!'){
                console.log('Not confirmed, stopping');
                process.exit(1);
            }
            console.log('deploying now...');
            deploy_contract(connection, tokensale, gasprice, function(deployed){
                if(deployed) {
                    console.log('Contract transactionHash: ' + deployed.transactionHash);
                    connection.close();
                    console.log('Done.');
                }
            });


        }

    }
);
