#!/bin/bash

curlurl() {

        if [ $2 ]; then

                curl -H "Content-Type: application/json" -u asterisk:asterisk http://localhost:8088$1 -d `echo $2`

        else

                curl -u asterisk:asterisk http://localhost:8088$1 -X POST

        fi

}


wurst() {

        bodySip="""{\"endpoint\":\"pjsip/$2\",\"channelId\":\"sip2id_1\",\"app\":\"refertest1\",\"originator\":\"$1\"}"""

        echo $bodySip

        curlurl /ari/channels/create $bodySip

        sleep 1

        curlurl /ari/bridges {'"'bridgeId'"':'"'bridge1id_1'"'}
        # curlurl /ari/bridges/bridge1id_1/addChannel {'"'channel'"':'"'$1'"'}


        # curlurl /ari/bridges/bridge1id_1/addChannel {'"'channel'"':'"'sip2id_1'"'}

        curlurl /ari/channels/sip2id_1/dial
}


delete() {
	curl -X DELETE -v -u asterisk:asterisk http://localhost:8088/ari/channels/sip2id_1
	curl -X DELETE -v -u asterisk:asterisk http://localhost:8088/ari/bridges/bridge1id_1
}

origChannelid=""

websocat "ws://localhost:8088/ari/events?api_key=asterisk:asterisk&app=refertest1" |

        while IFS= read -r line

        do
		echo $line
                type=`echo $line |jq -r .type`
                channelid=`echo $line |jq -r .channel.id`
                destination=`echo $line |jq -r .channel.dialplan.exten`

                echo $type channelId: $channelId

                if [ 'StasisEnd' == $type ] && [ $channelid != 'sip2id_1' ]; then

			echo Delete anything!

			# delete

		fi

                if [ 'StasisStart' == $type ]; then

                        echo "We got Stasis Start"

                        if [ $channelid != 'sip2id_1' ]; then

                                wurst $channelid $destination

                        fi

                fi
                if [ 'ChannelStateChange' == $type ]; then

                        if [ $channelid == 'sip2id_1' ]; then
                		state=`echo $line |jq -r .channel.state`

				if [ $state == 'Up' ]; then

                                        echo "Channel got ansered"
				fi
                        fi

                fi
                if [ 'ChannelTransferWURST' == $type ]; then
                        echo "We got Channel Transfer"


                        # channelid=`echo $line |jq -r .referred_by.source_channel.id`
                        #
                        # curlurl /ari/channels/$channelid/transfer_progress {'"'states'"':'"'channel_progress'"'}
                        #
                        #
                        # # sip2id_2 aus bridge1id_2 entfernen
                        # curlurl /ari/bridges/bridge1id_2/removeChannel {'"'channel'"':'"'sip2id_2'"'}
                        # #
                        # # # sip2id_2 in bridge1id_1 hinzufügen
                        # curlurl /ari/bridges/bridge1id_1/addChannel {'"'channel'"':'"'sip2id_2'"'}
                        # #
                        # # transfer_progress mit channel_answered
                        # curlurl /ari/channels/$channelid/transfer_progress {'"'states'"':'"'channel_answered'"'}
                        #
                        #
                        # curl -X DELETE -v -u asterisk:asterisk http://localhost:8088/ari/bridges/bridge1id_2

                fi

        done


