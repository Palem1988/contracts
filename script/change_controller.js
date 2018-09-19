const cli = require('readline-sync');
const Connection = require('./eth_connection');
const token = require('./contracts/token');
const tokensale = require('./contracts/tokensale');
const owned = require('./contracts/owned');

const environment = 'foundation'; // ropsten/foundation, change to foundation to deploy to real
var mnemonics = cli.question('Enter your mnemonics or pkey for '+environment+' account:');
var connection = new Connection(mnemonics, environment);

var deployed_token = connection.web3.eth.contract(token.abi).at(connection.config.token);
var deployed_tokensale = connection.web3.eth.contract(tokensale.abi).at(connection.config.tokensale);

deployed_token.controller(function(error,result){
        if(error){
            console.log(error);
            process.exit(1);
        }else{
            console.log( 'Token address '+ connection.config.token );
            console.log( "Current controller is: "+result);

            var new_controller = cli.question('Enter new controller address for '+environment+ ': ');

            connection.web3.eth.contract(owned.abi).at(new_controller).owner(function(error, owner){
                console.log( 'New controller address '+ new_controller + ' have owner: '+owner.toUpperCase());

                if(owner.toUpperCase()!='0X' && owner.toUpperCase()!=connection.config.creator.toUpperCase()){
                    console.log( 'Unexpected address '+ owner.toUpperCase() );
                    process.exit(1);
                }

                var use_contract, using;

                if(result.toUpperCase() == connection.config.creator.toUpperCase()){
                    use_contract = deployed_token; using = 'IZX Token';
                }else if(result.toUpperCase() == connection.config.tokensale.toUpperCase()){
                    use_contract = deployed_tokensale;  using = 'Crowdsale';
                }else{
                    console.log( 'Unexpected address '+ result.toUpperCase() );
                    process.exit(1);
                }
                
                var gasprice = cli.question('Enter gas price in gwei:');
                var yesno = cli.question('Enter Yes! to change token controller to '+new_controller+' calling '+using+ ' contract ('+ use_contract.address +
                    ') in '+environment+ ' with these parameters: ');
                if(yesno!='Yes!'){
                    console.log('Not confirmed, stopping');
                    process.exit(1);
                }

                use_contract.changeController.sendTransaction(new_controller, {from: connection.address, gas: 40000, gasPrice: connection.web3.toWei(gasprice, 'gwei')},
                    function(error, result){
                        console.log(error, result);
                        if(result) {
                            connection.close();
                            console.log('Done.');
                        }
                    }
                );

            });





        }

    }
);

