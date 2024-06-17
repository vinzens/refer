#!/bin/bash

curlurl() {

        if [ $2 ]; then

                curl -H "Content-Type: application/json" -u asterisk:asterisk http://localhost:8088$1 -d `echo $2`

        else

                curl -u asterisk:asterisk http://localhost:8088$1 -X POST

        fi

}


wurst() {

        bodySip="""{\"endpoint\":\"pjsip/$2\",\"channelId\":\"sip2id_2\",\"app\":\"refertest2\",\"originator\":\"$1\"}"""

        echo $bodySip

        curlurl /ari/channels/create $bodySip

        sleep 1

        curlurl /ari/bridges {'"'bridgeId'"':'"'bridge1id_2'"'}
        curlurl /ari/bridges/bridge1id_2/addChannel {'"'channel'"':'"'$1'"'}


        curlurl /ari/bridges/bridge1id_2/addChannel {'"'channel'"':'"'sip2id_2'"'}

        curlurl /ari/channels/sip2id_2/dial
}


delete() {
	curl -X DELETE -v -u asterisk:asterisk http://localhost:8088/ari/bridges/bridge1id_2
}

origChannelid=""

websocat "ws://localhost:8088/ari/events?api_key=asterisk:asterisk&app=refertest2" |

        while IFS= read -r line

        do
		echo $line
                type=`echo $line |jq -r .type`
                channelid=`echo $line |jq -r .channel.id`
                destination=`echo $line |jq -r .channel.dialplan.exten`

                echo $type channelId: $channelId

                if [ 'StasisEnd' == $type ] && [ $channelid != 'sip2id_2' ]; then

			echo Delete anything!

			delete

		fi

                if [ 'StasisStart' == $type ]; then

                        echo "We got Stasis Start"

                        if [ $channelid != 'sip2id_2' ]; then

                                wurst $channelid $destination

                        fi

                fi
                if [ 'ChannelStateChange' == $type ]; then

                        if [ $channelid == 'sip2id_2' ]; then
                		state=`echo $line |jq -r .channel.state`

				if [ $state == 'Up' ]; then

                                        echo "Channel got ansered"
				fi
                        fi

                fi

        done


