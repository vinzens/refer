

# Asterisk SIP Refer Feature Proposal
## Disclaimer

This is a draft for the community feature request to implement SIP REFER within ARI.

The implementation would be done by us, not by sangoma, but pushed to github so anyone could use this handling.

## Problem Description

### Setup Description

When using Asterisk with ARI in a single Asterisk instance or in a Asterisk cluster there is a problem handling SIP Refer. In order to address this issue we came up with an idea we would like to present to you. Please find our proposal below.

Any comments or ideas are welcome.

#### Attended Transfer

In our call scenario we have a call from Alice to Bob, where the call from Alice is placed in a stasis application.
The stasis application created a PJSIP channel using `ari/channels/create` and called the "dial" command in order to initiate the call towards Bob.
The channels of Alice and Bob are both answered and put into a bridge.
Bob put Alice on hold and placed a new call to Charlie.
This call is controlled by ARI the same way as the call with Alice and Bob.

Now Bob sends a "REFER" request to the asterisk in order to connect Alice and Charlie.

In general, there are two different scenarios we need to cover now. 
1. Single Asterisk instance
2. Multiple Asterisk instance

Both scenarios are described later on.

At the time The refer hits the asterisk we do have follow setup:

First Call initiated by alice:

Alice -> < Leg A > -> simple Bridge 1 -> < Leg B > -> Bob

As well as

Bob -> < Leg C > -> simple Bridge 2 -> < Leg D > -> Charlie

In this case the leg B is put on Hold so Bob is able to actively call Charlie
Leg A and Leg C is placed into a Stasis Application.
Leg B and Leg D are created by Stasis.

Bridge 1 and 2 are created by Stasis and all Legs are put into the bridge by Stasis. There is no AMI or Dialplan Application other than Stasis Involved.

In Scenario 1 where there is only a single Asterisk instance, both Bridges and all Channels are within this single asterisk. Asterisk would be able to resolve all channels.

In scenario 2 Leg A and Leg B as well as Bridge 1 are running on  one asterisk instance, where Leg C and D as well as Bridge 2 are running on an other asterisk instance. Here the asterisk cannot resolve all the channels needed for the refer handling.

#### Blind Transfer

Within Blind transfer the scenario is easing up a lot.

At the time the SIP Refer hits the Asterisk there is no second call running what needed to be resolved anyhow. At the time, Stasis needs to get the information the setup looks like
Alice -> < Leg A > -> simple Bridge 1 -> < Leg B > -> Bob

No other Legs or bridges are involved.


### Lack of functionality

At the moment Asterisk offers no way to actively control the transfer attempt.
There is no event which provides access to the transfer state or command to control the state of the transfer.

### Scenarios we are ignoring at the moment

for attended transfer it might be, Alice and Bob are not the only ones being in this bridge. At the Moment Bob sends the Refer, there might be in addition to Alice and Bob others the bridge 1 for e.g. a conference Call. This is no scenario we are covering here. So far this is not covered by [`refer-to` (RFC 3515)](https://datatracker.ietf.org/doc/html/rfc3515) as we understand this.

## Solution Proposal

### Missing information and control

#### ARI Event

As described earlyer there are two different scenarios what are relevant to split up. For a single Asterisk instance it would make sense to push as much information as possible within the first ARI Event in order to avoid unnecessary interaction or tracking state for all ongoing calls.

ARI should emit an event when a new transfer process is initiated.
The event could be named `ChannelTransfer`.

Within SIP the transfer is described by 
* [`refer-to` (RFC 3515)](https://datatracker.ietf.org/doc/html/rfc3515)
* [`referred-by` (RFC 3892)](https://datatracker.ietf.org/doc/html/rfc3892)




##### Attended Single Asterisk

If the asterisk is able to resolve all involved channels, all Channel objects should be included within the resulting ChannelTransfer ARI Event.
Within the ARI Event the requested information as well as the channel objects and Bridges could be pushed to ARI, even though this might blow up the ARI Event size.


##### Attended Multi Asterisk

Since the Asterisk cannot resolve the Channel objects the referer requests to connect, the ARI Application MUST keep track if all ongoing channels and their corresponding protocol ID in order to manually connect Channels 

The ARI Event therefor MUST contain the requesting Channel Object with its corresponding connected-channel and Bridge ID, as it must be for a single Asterisk, but in different to the referred to Channel Objects Asterisk can only provide all information presented by the Refer Request. For SIP this would be the protocol-id and optionally the SIP Parameter: Request Line or To-Tag


##### Blind

The asterisk must include both inflicted Channel Objects and the destination requested by Bob.  


#### ARI Control

To control the state of the transfer there must be a way to control the state within asterisk which must result in SIP Notify messages sent out to Bob.

To fulfill the minimal requirements of RFC3515, any of the following SIP-Frag codes must be able to be set:

* channel_progress  -> 100 Trying
* channel_answered -> 200 OK
* channel_unavailable -> 503 Service Unavailable
* channel_declined -> 603 Declined

It is beneficial to include code channel_not_found in order to signal destinations not found.

The command could be implemented under the `/ari/channels/{channelId}/transfer` route in the REST interface and takes the status word as a query parameter or request body. In case of SIP these updates MUST result in a Notify Message send out to Bob on order to fulfill the RFC requirements.

### Configuration
We propose two options that can be used individually and in combination to configure the transfer handling.

We prefer the introduction of a new Dialplan Function what changes the behaviour. This function would change the current Refer handling to the ARI handling. A name for this function could be "TRANSFERHANDLING()" and it takes values "" (empty), "default", "ari-only" where default would be the default value.

This Function can be set via Dialplan, within PJSIP Channel driver "set_var" section as well as for ARI Created channels within the Channel_vars.


### Sample ARI Event Data Model

```json
{
  "id": "ChannelTransfer",
  "description": "transfer on a channel.",
  "properties": {
    "state": {
      "required": false,
      "type": "string",
      "description": "Transfer State"
    },
    "refer-to": {
      "required": true,
      "type": "refer-to",
      "description": "Refer-To Information with Optionally both inflicted Channels"
    },
    "referred-by": {
      "required": true,
      "type": "referred-by",
      "description": "Referred-By SIP Header according rfc3892"
    }
  }
}
```

```json
{
  "id": "refer-to",
  "description": "transfer destination requested by transferee",
  "properties": {
    "requested-destination": {
      "protocol-id": {
        "required": false,
        "type": "string",
        "description": "the requested protocol-id by the referee in case of SIP channel, this is a SIP Call ID, Mutually exclusive to destination"
      },
      "destination": {
        "required": false,
        "type": "String",
        "description": "Destination User Part. Only for Blind transfer. Mutually exclusive to protocol-id"
      },
      "additional-protocol-params": {
        "required": false,
        "type": "??",
        "description": "List of additional protocol specific information"
      }
    }
  },
  "destination-channel": {
    "required": false,
    "type": "channel",
    "description": "The Channel Object, that is to be replaced"
  },
  "connected-channel": {
    "required": false,
    "type": "channel",
    "description": "Channel, connected to the to be replaced channel"
  },
  "bridge": {
    "required": false,
    "type": "bridge",
    "description": "Bridge connecting both destination channels"
  }
}

```

```json
{
  "id": "referred-by",
  "description": "transfer destination requested by transferee",
  "properties": {
    "source-channel": {
      "required": true,
      "type": "channel",
      "description": "The channel on which the refer was received"
    },
    "connected-channel": {
      "required": false,
      "type": "channel",
      "description": "Channel, Connected to the channel, receiving the transfer request on."
    },
    "bridge": {
      "required": false,
      "type": "bridge",
      "description": "Bridge connecting both Channels"
    }
  }
}

```
### ARI Command

#### Path

POST /channels/{channelId}/transfer
#### Path parameters
Parameters are case-sensitive.

* channelId: string - Channel's id
#### Query parameters

* states: string - Set the state of the transfer
#### Error Responses
Possible Return Codes

* 404 - Channel not found
* 409 - Channel not in a Stasis application
* 412 - Channel in invalid state

### Asterisk Behavior (PJSIP Only)
When receiving a SIP REFER request on Asterisk, the asterisk checks whether the refer is handled internally or sent to ARI.
If so, the Asterisk generates the ARI event as well as the `202 Accepted` SIP response to signal the endpoint the refer is handled.
Asterisk must start a timer (duration tbd) in which ARI must respond with at least a `transfer` command containing a `channel_progress` state.

When ARI receives the command to update the status, Asterisk sends out the SIP Notify containing the SIP-Frag and emits the `ChannelTransfer` ARI event with additional `state` object containing the actual transfer state.
If the updated state contains a SIP response code >= 200 the transfer is finished and asterisk awaits either the SIP Bye from the endpoint or a DELETE command on ARI for this channel.
Either way, asterisk does not need to track the state anymore.


### Error Handling
If the aforementioned timer ends, asterisk sends out a SIP Notify containing the SIP-Frag `SIP/2.0 503 Service Unavailable` (maybe 408 request timeout) so the endpoint gets informed about the error.
An ARI event `ChannelTransfer` containing status `channel_unavailable` must be sent as well.


### Side Effects

At the moment, there are Side effects executes by asterisk like CEL or AMI Events. 

In case of a single asterisk instance, these events should not break. CDR / CEL Events should be written as they are now. AMI Events should be emitted as they are now emitted if there is no ARI involved where Dial() handles the refer. However, no Additional side effects should be generated either.

In case of a multi asterisk instance installations these events cannot be thrown as it would be a single asterisk since the Asterisk just know about single Channels but nothing about the setup. CDR Information or similar information must be collected elsewhere. 


### ARI Service

#### Single Asterisk Setup

In Case the service is connected only to a single Asterisk, or all Calls as served within the same Asterisk instance. All relevant data are present with the first ARI Event. The Service could react in any way, the fastest way would be to place Alice and Charlie into one bridge and delete the held channel to Bob, delete the second bridge as well as send out the new status `channel_answered` to the active channel to Bob. In this case the phone should hang up. 

#### Multiple Asterisk Setup

When the service is connected to multiple Asterisk instances. The service MUST keep track of all ongoing channels, what might be inflicted within a transfer. If one channel is not controlled by ARI, there is no way to bridge both channels. In this case the service must respond to the transfer request with an `channel_unavailable` state update. If all related channel are in control of ARI, the service needs to place a new call, connecting both Asterisk instances. There is no automatic way to do this by asterisk.
