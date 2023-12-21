#import "NodeGroup.h" 
#import "PredictorNode.h"
#import "TemporalNode.h"
#import "TerminalGroup.h"
#import "TerminalNode.h"
#import "UnaryNode.h"
#import "AgentModelSwarm.h"
#import <collections.h>
#include <stdio.h>
#include <strings.h>

@implementation NodeGroup

// a nodegroup has a node to implement some of its functionality
// in this case the nodeGroup acts as a proxy for the node.  The node here 
// is not added to the agentModel node list, so it does not get sent
// meaningless messages

+createBegin: (id) aZone
{
    return [super createBegin: aZone];
}

-setAgentModel: (id) aModel
{
    agentModel = aModel;
    return self;
}

-(boolean) setNodeNumber: (long) aNumber
{
    nodeNumber = aNumber;
    //    [agentModel addNodeGroup];
    return True;
}   
      
-createEnd
{
   return [super createEnd];
}

-buildObjects
{
    nodeList = [List create: [agentModel getZone]];
    rewardList = [List create: [agentModel getZone]];
    previousNodeList = [List create: [agentModel getZone]];
    // May 8 2002
    interest = [agentModel getInterest];
    terminalNode = nil;
    proxyNode = nil;
    topGroup = False;
    finalGroup = False;
    fired = False;
    preFired = False;
    inhibited = False; 
    lastInhibited = False;
    inputsRemoved = False;

    higherValue = False;

    improvedNodeCount = 0;

    hypActivePredicted = False;
    hypPassivePredicted = False;     
    hypSuspendedPredicted = False;
    hypSupressed = False;
    hypActiveSupressed = False;
    hypLastActiveSupressed = False;
    hypMatched =False;
    hypActive=False;
    hypStrength=0;
    hypQreturn=0;
    hypFired = False;  

    preventTemporalConnect = False;
    activePredicted = False;
    passivePredicted = False;     
    suspendedPredicted = False;
    updateTemporalSupressed = False;
    supressed = False;
    temporallySupressed = False;
    temporallyActivated = False;
    activeSupressed = False;
    activeActionSupressed = False;
    activeTemporallySupressed = False;
    activeSuppressedAtStart = False;

    lastActiveTemporallySupressed = False;
    lastActiveSupressed = False;
    removed = False;
    firstNode = nil;
    suspended = True;
    matched =False;
    realActive=False;
    lastRealActive=False;
    previousRealActive=False;
    strength=0;
    Qreturn=0;
    averageReturn=0;
    averageReward=0;
    temporalQreturn=0;
    miss = False;
    // Every temporal node group must set this to zero when created
    temporalActivationCount = 0;
    predictedByFinalisedChain = 0;
    predictedByNonFinalisedChain = 0;
    lastPredictedByFinalisedChain = 0;
    lastPredictedByNonFinalisedChain = 0;
    primaryNode = nil;
    resetCount = 0;

    accuratelyPredictedOk = False;
    accuratelyTemporallyPredictedOk = False;
    return self;
}

// This is not very useful as it is reset in realDeactivate

-(boolean) getPredictedByFinalisedChain
{
  return predictedByFinalisedChain;
}

-(int) getPredictedByNonFinalisedChain
{
  return predictedByNonFinalisedChain;
}

// because where this is used flag is after realdeactivate
// we must use last value.

-(int) getLastPredictedByFinalisedChain
{
  return lastPredictedByFinalisedChain;
}

// because where this is used flag is after realdeactivate
// we must use last value.

-(int) getLastPredictedByNonFinalisedChain
{
  return lastPredictedByNonFinalisedChain;
}

-setPredictedByFinalisedChain: (boolean) aBoolean
{
  if ([agentModel getDebug])
    printf("\n NodeGroup: %ld predicted by finalised chain time: %ld", 
	   nodeNumber, getCurrentTime()); 

  predictedByFinalisedChain = aBoolean;
  return self;
}

-incrementPredictedByNonFinalisedChain
{
  if ([agentModel getDebug])
    printf("\n NodeGroup: %ld predicted by NON finalised chain time: %ld", 
	   nodeNumber, getCurrentTime()); 

  predictedByNonFinalisedChain++;
  return self;
}

-realDeactivate
{

 // This should only be done by nodeGroups.	
 // If we are matched when we are deactivated
 // first match the terminal node so it can fire.
 // Since deactivate is sent 

 // Don't know why this was her, moved to setMatched so terminal
 // groups can send support.
 //    [self terminalNodeSetMatched: matched];

  if ([proxyNode respondsTo: M(isTerminal)])
    [(TerminalGroup *) self setPredictionPassedFlag: False];

  lastPredictedByNonFinalisedChain = predictedByNonFinalisedChain;
  lastPredictedByFinalisedChain = predictedByFinalisedChain;
  predictedByNonFinalisedChain = 0;
  [self setPredictedByFinalisedChain: False];

  preventTemporalConnect = False;

  activePredicted = False;
  passivePredicted = False;     
  suspendedPredicted = False;
  fired = False;
  preFired = False;
  lastInhibited = inhibited;
  inhibited = False; 
  
  [proxyNode clearPredictors];
  
  [proxyNode setSupressed: False];  
  [proxyNode setNarySupressed: False];
  [proxyNode setTemporallySupressed: False];  
  [proxyNode setUpdateTemporalSupressed: False];
  previousRealActive = lastRealActive;
  lastRealActive = realActive;

  [self setRealActive: [self getMatched]];
  [proxyNode realDeactivate];

  [proxyNode setPreviousRealActive: previousRealActive]; 
  [proxyNode setLastRealActive: lastRealActive]; 
  [proxyNode setRealActive: realActive]; 

  [self resetMatched: False];
  accuratelyPredictedOk = False;
  accuratelyTemporallyPredictedOk = False;

  Qreturn = 0;
  temporalQreturn = 0;
  
  return self;
}

// Dec 20 2000 - removed following from deactivate above, changed condition
// from matched to realActive to allow additional condition of 
// ensuring the chains prediction is correct.

-checkActivationCount
{
  id prediction;
  id inputNode;

  // TemporalGroups which are top groups must have a number of trials
  // to allow the terminalGroup to determine if adding it has provided
  // any improvement on any of its inputs.
  // Node that the temporalActivationCount applies to the group
  // not the individual nodes and is updated each time the chain
  // is followed to completion
  
  if ([agentModel getDebug] && ([proxyNode respondsTo: M(isTemporal)]))
    printf("\n about to update temporalActivationCount for node: %ld, realActive: %d", nodeNumber, realActive);
  

  if ([proxyNode respondsTo: M(isTemporal)] &&
      realActive)
    {
      inputNode = [[[proxyNode getInputList] getFirst] getNode];
      // Jan 15 2000 - removed following, speed up extending
      // if first node prediction does not occur very often
      prediction = [[[[self getTerminalGroup] getFirstNode] 
      		      getPrediction] getFirstNode];
      if ((([prediction respondsTo: M(isTemporal)] 
	    && [prediction getFirstInputMatchedNow])
	   || (![prediction respondsTo: M(isTemporal)] 
	       && [prediction getMatched]))
	  // A cycle (your input being re-matched) counts as an activation
	  ||  (([inputNode respondsTo: M(isTemporal)] 
		&& [inputNode getFirstInputMatchedNow])
	       || (![inputNode respondsTo: M(isTemporal)] 
		   && [inputNode getMatched])))
	// if (realActive)
	{
	  if ([agentModel getDebug])
	    printf("\n incrementing activationcount for node: %ld to %d",
		   nodeNumber, (temporalActivationCount + 1));
	  if (temporalActivationCount 
		  < ((double) [agentModel getTemporalActivationThreshold] 
		     * [agentModel getRemovalFactor]))
	    temporalActivationCount++; 
	  // reset the reset count
	  resetCount = 0;
	}
    }

  return self;
}

-addToConnectList
{

  id predict;

// send this message to nodes and node groups to allow a state to
// be represented by a single group, but only include nodes from the same
// group once.  REMOVE the addtopredictorlist code in FIRE.

// Need to allow the nodeGroup to copy one of its nodes
// for a different effector (as well as prediction).

// This should only be done if one of the nodes in the group made a 
// non-suspended prediction

// Note: that unary node groups are never suspended (not at the minute anyway)
// if they to be suspended, remember that they are created without
// a first node so the else condition will not work, and they will
// not be added to the predictorList!


  if ([agentModel getDebug]) {
    if ([proxyNode respondsTo: M(isTemporal)]
	&& [proxyNode getTemporallyRealActive])
      printf("\n nodegroup %ld, realactive: %d, supressed: %d \n matched: %d, \n suspended: %d, fired: %d,\n activeSupressed: %d \n lastactivesupressed: %d\n temporallySupressed: %d\n activeTemporallySupressed: %d\n lastActiveTemporallySupressed: %d\n narySupressed: %d",
		 nodeNumber, realActive, supressed, matched,
		 suspended, fired, 
		 activeSupressed, lastActiveSupressed, temporallySupressed,
		 activeTemporallySupressed, lastActiveTemporallySupressed,
		 narySupressed);
    else {
      if (realActive)
	printf("\n nodegroup %ld, realactive: %d, supressed: %d \n matched: %d, \n suspended: %d, fired: %d,\n activeSupressed: %d \n lastactivesupressed: %d\n temporallySupressed: %d\n activeTemporallySupressed: %d\n lastActiveTemporallySupressed: %d\n narySupressed: %d",
		 nodeNumber, realActive, supressed, matched,
		 suspended, fired, 
		 activeSupressed, lastActiveSupressed, temporallySupressed,
		 activeTemporallySupressed, lastActiveTemporallySupressed,
		 narySupressed);
    }
  }

// Once a chain is complete, it can be copied as a predictor of other nodes
// Only terminal nodes can be copied, so terminal groups add themselves
// to a temporalPredictorList in AgentModel::addToTemporalPredictorList.

   // May 20 2002 - not any more:

   //   if ([proxyNode respondsTo: M(isTemporal)]) 
   //  return self;

// See TerminalGroup.m addToTemporalConnectList for details of copying 
// terminalNodes to predict other groups.

   if ([proxyNode respondsTo: M(isTemporal)]) {
     if ([proxyNode getTemporallyRealActive]
	 // June 17 2002 add following condition:
	 && !lastActiveSupressed) {
       //  June 18 2002 - remove following condition:
       //	 && !lastActiveTemporallySupressed) {
       if (!suspended)
	 // July 16 - do not copy temporal nodes!
	 return self;
	 //[[agentModel getPredictorList] addLast: self];
       else {
	 // June 14 - here also prevent duplicate chains forming
	 // for a particular prediction (eg have 5,5-7 and occurs the
	 // sequence 5,5,5,7
	 if ([firstNode getTemporallyFired]) {
	   predict = [firstNode getPrediction];
	   if (([predict respondsTo: M(isTemporal)]
		// Don't rely on FIMN 
		&& [[[[predict getInputList] getFirst] getNode] getMatched])
	       || (![predict respondsTo: M(isTemporal)]
		   && [predict getMatched])) {
	     if ([agentModel getDebug])
	       printf("\n NodeGroup setCreateTemporalOk: %ld", nodeNumber);
	     [agentModel setCreateTemporalOk: False];
	   }
	 }
       }
     }
   } else {
     if (realActive
       	 && !lastActiveSupressed
	 && !lastActiveTemporallySupressed)
       { // June 20 - Allowing inhibited groups to copy predictors
	 //  && !lastInhibited) {
	 [[agentModel getPredictorList] addLast: self];
       }
   }

   return self;
}

-constructExtendList: (id) extendList
{

  if ([agentModel getDebug])
    printf("\n nodegroup %ld received constructExtendList sus: %d", 
	   nodeNumber, suspended);
 
  added = False; // allow only one node to be added

  // Nov 15 2000 - don't add nodes that are under finished active chains
  // or temporal nodes   
  
  // Mar 28 2002 - if unary, allow to be used for extensions prior
  // to being !suspended
 
  if (([proxyNode respondsTo: M(isUnary)] || 
       (!suspended && ![proxyNode respondsTo: M(isTemporal)]))
      && !lastActiveSupressed)
      // May 30 2001 - added following line - needs to be tested
    // June 18 2002 - removed, as chain may not be followed, do not
    // prevent nodes under them from being included here
    // so they can be included in lastExtendList.
    // && !activeTemporallySupressed) 
     [nodeList forEach: M(addToExtendList:) : (id) extendList];
  return self;
}

-(boolean) getAdded {
  return added;
}

-setAdded: (boolean) aBool {
  added = aBool;
  return self;
}

// return the maximum discounted terminal value for nodes in your group
// this may vary from node to node as it may only be updated for a node
// if it fired when the group was last firstInputMatched. 
// It makes no sense to call this for non-temporal nodes.

-(double) getMaxDiscountedTerminalValue 
{
  int count = 0;
  double max = -1000.0;

  count = [nodeList getCount];
  while (count > 0) {
    count--;

    if ([[nodeList atOffset: count] getDiscountedTerminalValue] > max)
      max = [[nodeList atOffset: count] getDiscountedTerminalValue];
  }

  return max;
}


// This is only for temporal nodes which are not sent the message
// connectPredictorList unless they are finalGroups as they
// are only copied to predict the next node in the temporal chain.
// As they are not sent connectPredictorList they must explicity
// copy nodes for different effectors. It is ok to base the predicition
// on any other node in the group (in this procedure the first node) 
// as they all predict the same thing.

// Changed 23 Nov 2000 - don't copy a node unless the next link 
// in the chain has its first input matched now.

-copyNode
{
  TemporalNode * node;
  id valueNode;
  
 // Don't copy  if one of your nodes fired, i.e matched the input and effector.
  if ([agentModel getDebug])
    printf("\n In copyNode for group: %ld, preFired: %d, fired: %d",
	   nodeNumber, preFired, fired);
  
  if ((![proxyNode respondsTo: M(isTemporal)] 
       // Dec 5	&& ![proxyNode respondsTo: M(isTerminal)])
       || !preFired))     
    return self;

  // Nov 23 2000 - don't copy if next link in chain not FIMN.
  if (terminalNode != nil)  {  // we are first group in chain
    if (![[[[proxyNode getInputList] getLast] getNode] getMatched])
      return self;
  }
  else  
    if (![[[[proxyNode getInputList] getLast] getNode] 
	   getFirstInputMatchedNow])
      return self;

  if (!fired) {
    if ([agentModel getDebug])
      printf("\n Copying Node in group : %ld.", nodeNumber);
    
    node = [firstNode copyNew: [agentModel getZone]];
    if ([agentModel getDebug])
      printf("\n Node created : %ld.", [node getNodeNumber]);
    
    [node setMatched: [proxyNode getMatched]];  
    if ([proxyNode respondsTo: M(isTerminal)])
      [node setMatched: [proxyNode getMatched]];
    else
      {
	[node setAcceptingMessages: 
		[proxyNode getAcceptingMessages]];
	[node setSecondInputMatchedNow: 
		[proxyNode getSecondInputMatchedNow]];
	[node setFirstInputMatchedNow: 
		[proxyNode getFirstInputMatchedNow]];    
	[node setWaitingOnFirstInput: 
		[proxyNode getWaitingOnFirstInput]];
	[node setWaitingOnSecondInput: 
		[proxyNode getWaitingOnSecondInput]];
      }
    [(PredictorNode *) node setSupported:
                         [agentModel getSelectedEffector]];
    
    if ([agentModel getDebug])
      printf("\n First node is: %ld, its prediction is: %ld",
	     [firstNode getNodeNumber], 
	     [[firstNode getPrediction] getNodeNumber]);
    [[firstNode getPrediction] addPredictor: node];
    [node setSuspended: [firstNode getSuspended]];
    [node setCorrect: False];
    [node setCorrectCount: 1];
    [node setRealActive: False];
    [[[firstNode getPrediction] getProxyNode] 
      suspendedPredictedBy: node];
    [node setSentSupport: True];
    
    if ([node respondsTo: M(isTerminal)]) {
      valueNode = [[[[[[[node getGroup] getProxyNode] 
			getInputList] getFirst] getNode] 
		     getGroup] findSimilarTerminalNode: node];
      if ((valueNode != nil)
	  // Apr 17 2001  
	  && [agentModel getCopyValues]) {
	[node copyValues: valueNode];
	[node setSuspended: [firstNode getSuspended]];
      }
    }
    
  }
  
  return self;
}     

-removeOwners
{
   [proxyNode removeOwners];
   return self;
}

-setPreFired: (boolean) aBoolean
{
   preFired = True;
   return self;
}


-connect
{

// The old connect would connect NOt even when not matched. 
// the idea here is to connect NOT only when matched (like AND)
// Each group that predicts another group will maintain a measure
// of its correctness, which is the percentage of correctly fired
// nodes of all fired nodes.  Any nodes which made incorrect predictions
// of this group are NOT anded with the node with the highest correct 
// percentage.  The nodes which made the incorrect prediction
// could possibly be copied to the new NOT group, but then if the 
// group is removed, these are lost.   


  // Sept 21 - only non-suspended groups create AND predictors
  // Mar 28 2001 - added code to allow unary nodes to create
  // AND nodes even if still suspended.
 

  if (!activeSupressed  
      && matched && (!suspended 
		     || [proxyNode respondsTo: M(isUnary)]))
    {
      if ([agentModel getDebug])
	printf("\n Node group %ld, doing connect suspended: %d", 
	       nodeNumber, suspended);
      if ([agentModel getDebug])
	printf("\n Node group %ld, doing connect", nodeNumber);
      [proxyNode connect];
    } 
  
  return self;
}

-temporalExtend
{

// This only applies to temporal groups.  They have just one node
// which makes predictions. If that node is temporally supressed
// it cannot be used again, only terminal nodes can be used for multiple 
// predictions (copied).  In actual fact, these nodes will only be active
// supressed once they have temporal 
// owners, so that condition is redundant here. 
// Top groups cannot be extended.
    
   if (![proxyNode respondsTo: M(isTemporal)])
       return self;

   if ([agentModel getDebug])
     printf("\n Temporal Node: %ld, doing temporal extend. topGroup: %d,\n finalGroup: %d, suspended: %d activeTemporallySupressed: %d\n activated: %d, temporallySupressed: %d,\n firstinputmatchednow: %d,\n waitingonSecond: %d, waitingOnFirst: %d, matched: %d,\n terminalGroupOk: %d ",
                  nodeNumber, topGroup, finalGroup, suspended,
                [proxyNode getActiveTemporallySupressed],
                [self getTemporallyActivated],
	    [proxyNode getTemporallySupressed],
	    [proxyNode getFirstInputMatchedNow],
	    [proxyNode getWaitingOnSecondInput],
	    [proxyNode getWaitingOnFirstInput],
	    matched,
	    ((terminalGroup == nil) || ![terminalGroup getSuspended]));

   // Feb 1 2001 - don't temporalExtend if realActive unless prediction
   // is matched now or chains for corridor tasks can grow too long.
   // eg: 12,5,5,5,5,5->2, if current chain is 5,5,5,5->3, 
   //      1 2 3 4 5 6   when we get to 6, FIM, and we extend to 

   if (!activeSupressed
       && ![proxyNode getTemporallySupressed]
       && [proxyNode getFirstInputMatchedNow]
       && topGroup
       && !finalGroup

       // Mar 1 2001 - if always following shortest path, there will
       // cases when the first node's activation count never reaches
       // the threshold, however, in other cases (when exploring a lot)
       // when want to wait until the first node's activation count
       // has reached the threshold. So, if by the time the group
       // reaches its temporalActivationthreshold the first node
       // has not been activated at least once, extend anyway.

       && [self getTemporallyActivated]
       && !matched)
     {
       if ([agentModel getDebug])
	 printf("\n Node group %ld, doing temporal extend ", nodeNumber);
       [proxyNode temporalExtend];
     }

   return self;
}

 
// Jan 18 2001 - top temporal groups of final chains
// need to tell their inputs to remove any unfinalised chains which
// predict them.
// This is because a chain may be predicting something, and may have
// even extended itself when a chain with a top group on one of its
// predictions is finalised. Now the extended chain may not predict
// this correctly, but a shorter version of it would, however, this 
// shorter version cannot form until the unfinished chain extends itself
// out completely and is removed.  To prevent this wait, unfinished
// chains which predict a node with a new finalised top group owner
// are removed.

-removeInputChains
{


  /*  April 22 2002 - removing this - I don't really have another solution
      however, with the other changes made on this date a shorter chain
      should be able to form if the longer chain's path is not followed,
      this implies that some random actions or random starting points should 
      selected at least occasionally.

  if (![proxyNode respondsTo: M(isTemporal)])
    return self;
  
  // REALLY Only need to do this once.
  
  if (topGroup
      && finalGroup
      && matched
      && !inputsRemoved)
   {
     inputsRemoved = True;
     if ([agentModel getDebug])
       printf("\n Node group %ld, new final group removing 
             unfinished chains which predict input", nodeNumber);
     [[[[[proxyNode getInputList] getFirst] 
	 getNode] getGroup] removeUnfinishedChains];
   }
  */

  return self;
}

// Feb 1 2001 - check if reset in last match cycle
// if we were and our prediction is matched (need to check this afterwards
// as it may be matched after the chain above it) then set predictionPassed
// flag to True.
// see NodeGroup:checkTemporalRemove

-checkForMatchReset 
{

  id predict = nil;

  
   // Feb 1 2001 - While here, also check if reset in last match cycle
   // (which will happen if our previous link's action is not selected or
   //  the action was selected and the next link just not matched). 
   // if we were and our prediction is matched (need to check this afterwards
   // as it may be matched after the chain above it) then set predictionPassed
   // flag to True.
   // see NodeGroup:checkTemporalRemove

  // May 16 2002

  if ([[self getProxyNode] respondsTo: M(isTemporal)] 
      && [proxyNode getResetChain]
      // June 1 2002 - only set prediction passed if chain
      //               path followed.
      // July 2 2002 - note this need not be the top group -
      // just the group which fired
      && [self getPrimaryFired]) {
    predict = [[[[self getTerminalGroup] getFirstNode] 
		 getPrediction] getProxyNode];
    if (([predict respondsTo: M(isTemporal)]
	 // Don't rely on FIMN 
	 && [[[[predict getInputList] getFirst] getNode] getMatched])
	|| (![predict respondsTo: M(isTemporal)]
	    && [predict getMatched])) {
      if ([(TerminalGroup *) [self getTerminalGroup] 
			     getPredictionPassedFlag])
	return self;

       // only do this if the most recent extension is the same
       // as the first group, otherwise it is not
       // a homogenous corridor (eg: we get 8,12,10->12 in 
       // ring5x4.txt)

       if ([agentModel getDebug])
	 printf("In group: %ld setting prediction passed homo: %d",
		nodeNumber, 
		[[[[[[self getTopGroup] getProxyNode] getInputList] 
		    getFirst] getNode] getGroup]
		== [[[[[[[self getTerminalGroup] getTemporalGroup] 
			 getProxyNode] getInputList] getLast] 
		      getNode] getGroup]);

       if ([[[[[[self getTopGroup] getProxyNode] getInputList] 
	       getFirst] getNode] getGroup]
	   == [[[[[[[self getTerminalGroup] getTemporalGroup] getProxyNode] 
		   getInputList] getLast] getNode] getGroup])
	 // Ok - don't remove recent extension
	 [(TerminalGroup *) [self getTerminalGroup] 
			    setPredictionPassedFlag: True];
     }
  }
   
   return self;
}

// This will go through the predictor list and ask unfinished chains
// to remove themselves.

-removeUnfinishedChains
{
  id tempList;
  int count = 0;

  tempList = [[proxyNode getPredictorList] copy: [self getZone]];
  count = [tempList getCount];
  while (count > 0) {
    count--;
    if ([[tempList atOffset: count] respondsTo: M(isTerminal)])
      [(TerminalNode *) [tempList atOffset: count] removeIfUnfinished];
  }
  [tempList drop];
  return self;
}

-(long) getTemporalActivationCount
{
  return temporalActivationCount;
}

// Mar 1 2001 - if always following shortest path, there will
// cases when the first node's activation count never reaches
// the threshold, however, in other cases (when exploring a lot)
// when want to wait until the first node's activation count
// has reached the threshold. So, if by the time the group
// reaches its temporalActivationthreshold the first node
// has not been activated at least once, extend anyway.


-(boolean) getTemporallyActivated 
{

  // Now base this on whether the firstTerminal node has enough 
  // trials - check the TrendForThis to see if enough trials yet

  // NOTE: for this to work for homogeneous corridors must not
  // check for highervalue 

  // April 4 2002 - store flag indicating whether this extension 
  // has passed activation tests

  if ((self == [self getTopGroup])
      && (temporallyActivated == False)) { // once activated - always activated
    temporallyActivated = [[[self getTerminalGroup] getFirstNode] getTemporallyActivated];
    if ([agentModel getDebug] && temporallyActivated)
      printf("\n Setting nodeGroup: %ld to temporallyActivated", nodeNumber);

  }
  return temporallyActivated;

}

-checkMatched
{
  if (![proxyNode respondsTo: M(isTerminal)] && 
      ![proxyNode respondsTo: M(isTemporal)] &&
      ![proxyNode respondsTo: M(isUnary)]) 
    [(NaryNode *) proxyNode checkMatched];
  return self;
}

-setPreventTemporalConnect: (boolean) aBoolean 
{

  preventTemporalConnect = aBoolean;
  return self;
}

-(boolean) getPreventTemporalConnect {
  return  preventTemporalConnect;
}

-temporalConnect
{

  if ([agentModel getDebug]) {
    if ([proxyNode respondsTo: M(isTemporal)]) {
      fprintf(stdout,"\n Node %ld, doing temporalConnect. activeS: %d, \n matched: %d, isTemporal: %d, \n firstinputmatched: %d, suspended: %d, finalGroup: %d,\n prevented: %d",
	      nodeNumber, activeSupressed, matched,  
	      [proxyNode respondsTo: M(isTemporal)],
	      [proxyNode getFirstInputMatchedNow], suspended, finalGroup,
	      preventTemporalConnect);
    } else {
      fprintf(stdout,"\n Node %ld, doing temporalConnect. activeS: %d,\n matched: %d ptc: %d ",  
	      nodeNumber, activeSupressed, matched, preventTemporalConnect); 
    }
  }
  
  // Needed to split the following code, the && was not short-circuiting
  // and getFirstInputMatchedNow was being sent to non-temporal nodes.
  
  // Here is where activeSupressed is used, to prevent nodes under
  // the top group of final chains from creating chains.

  if (!activeSupressed
      // April 22 2002 - don't prevent activetemporallysuppressed nodes
      // from creating temporal chains to predict them
      // && !activeTemporallySupressed && 
      && !preventTemporalConnect) {
    if ([proxyNode respondsTo: M(isTemporal)]) {
      if (!suspended
	  && [proxyNode getFirstInputMatchedNow] 
	  && finalGroup)
	[proxyNode temporalConnect];
    }
    else {
      // Unary and Nary nodes
      if ((!suspended || [proxyNode respondsTo: M(isUnary)])
	  && matched)
	  [proxyNode temporalConnect];
    }
  }
  
  return self;
}

-connectPredictorList: (id) aList
{
 // Do not connect predictors to yourself unless you are not suspended
 // Except: unary nodes which can copy predictors when suspended

  if ([proxyNode respondsTo: M(isTemporal)])
    {
      // July 15 2002 - allow any  temporal groups prior to copy predictors
      if (([[self getTopGroup] getFinalGroup])
	&& (self == [self getTopGroup]))
	{
	  // June 24 - undid June 17 changes:
          if (// !activeSupressed 
	      //&& !activeTemporallySupressed 
	      !suspended
	      && [proxyNode getFirstInputMatchedNow])
	    [proxyNode connectPredictorList: aList];
	}
      else
	return self;
    }
  else {
    // June 6 commented following !activeSupressed
    // June 17 2002 - uncommented activeSupressed and added temporal:
    // June 24 - undid June 17 changes:
    if (// !activeSupressed
	// && !activeTemporallySupressed 
	// Unary groups can make copies even if suspended
        (!suspended || [proxyNode respondsTo: M(isUnary)])
	&& matched)
      [proxyNode connectPredictorList: aList];
  }

  return self;
}

// July 15 2002 - get the prvious group in temporal chains

-getPreviousGroup {

  if (topGroup)
    return nil;
  else
    return [[previousNodeList getFirst] getGroup];
}

-passUpPredictors
{
    [proxyNode passUpPredictors];
    return self;
}

-setNode: (id) aNode
{
    firstNode = aNode;

    [nodeList addLast: aNode];

    if ([aNode respondsTo: M(isUnary)])
        [self createUnaryProxy: aNode];
    else
        if ([aNode respondsTo: M(isTemporal)])
            [self createTemporalProxy: aNode];
	else
            if ([aNode respondsTo: M(isTerminal)])
                 [self createTerminalProxy: aNode];
            else
                 [self createNaryProxy: aNode];

// took this out as all nodes (except proxy nodes) are predicted by their
// groups only
//    [self movePredictors: aNode];

    [proxyNode setProxyGroup: self];
    [aNode addPredictor: self];
    
    return self;
}     



-create: (DetectorNode *) anInputDetector
{
//    This is for detector nodes which are created
//    without an existing node

   proxyNode = [UnaryNode createBegin: [self getZone]];
   [proxyNode setModel: agentModel];
   [proxyNode setFamily: [anInputDetector getFamily]];
   [(PredictorNode *) proxyNode setSuspended: True];
   [proxyNode setNodeNumber: nodeNumber];
   proxyNode = [proxyNode createEnd]; 
   
   [proxyNode buildObjects];
   
   [proxyNode addInput: anInputDetector];
   [anInputDetector addProxyOwner: proxyNode]; 
   [proxyNode setProxyGroup: self];

   return self;
}
 
-createUnaryProxy: (id) aNode
{

   proxyNode = [UnaryNode createBegin: [self getZone]];
   [proxyNode setModel: agentModel];
   [proxyNode setFamily: [aNode getFamily]];
   [(UnaryNode *) proxyNode setSuspended: True];
   [proxyNode setNodeNumber: nodeNumber];
   proxyNode = [proxyNode createEnd]; 
   
   [proxyNode buildObjects];
   
   [proxyNode addInput: [aNode getInputDetector]];
   [[aNode getInputDetector] addProxyOwner: proxyNode]; 
 
   return self;
}

// remember aNode is newly contructed TemporalNode with 
// prediction and inputs.

-createTemporalProxy: (id) aNode
{
   proxyNode = [TemporalNode createBegin: [self getZone]];
   [proxyNode setModel: agentModel];
   [proxyNode setType: [(TemporalNode *) aNode getType]];
                        // 0 is AND
   [proxyNode setNodeNumber: nodeNumber];      // this groups number  
   proxyNode = [proxyNode createEnd]; 

   [proxyNode buildObjects];
   [proxyNode setProxyGroup: self];
   // need to set the prediction for temporalProxy nodes
   // for Node::extendTemporal.
   [proxyNode setPrediction: [aNode getPrediction]];
   [proxyNode setMatched: True];

 // if this group has a Unary or Nary node as its second 
 // input, it needs a terminal node.

 // First a terminal node is constructed to predict the same thing
 // as the temporal node, then it is asked to create a group for itself
 // The group creates a proxy, which we then set up correctly. 
 // Once all that is done, the newly created TerminalNode is added to
 // the group just created. 

 // The input for terminal nodes is the secondInputNode of aNode
 // If the value of the secondinput is higher than the temporal 
 // or terminal nodes above it, these nodes will all be removed.
 // This input is used only for strength comparison, all matched,
 // supressed and other control messages come from this group.


   // December 1 : This node creation is proably not necessary
   // and the proxy node should suffice (with all these bits moved there)
   // as it is we have one additional node which doesn't really
   // do anything (this change is not critical though).
   // However: see set node below, most likely this node should be used
   // to predict something instead of creating a separate node
   // in connectTemporal: and:
   if (![[[[aNode getInputList] getLast] getNode] respondsTo: M(isTemporal)]) 
   {
     terminalNode = [TerminalNode createBegin: [self getZone]];
     
     if ([agentModel getDebug])
       printf("\n Creating new Terminal Node in \n NodeGroup::CreateTemporalProxy");
     [terminalNode setGrid: nil];
     
     [(Node *) terminalNode setX: 0 Y: 0];
     [(Node *) terminalNode setColor: 1];
     [terminalNode setModel: agentModel];
     [terminalNode setNodeNumber: 
		     [agentModel getNextNodeNumber: terminalNode]];
     if ([agentModel getDebug])
       printf("\n Creating new Terminal Node in \n NodeGroup::CreateTemporalProxy: %ld", nodeNumber);
     terminalNode = [terminalNode createEnd]; 

     [terminalNode buildObjects];
     
     // Dec 1 changed the folowing to use proxyNode rather than
     // the actual node in case it is removed  
     // The strength comparison is based on the node given here 
     [terminalNode addInput: 
		     [[[[[aNode getInputList] getLast] getNode] 
			getGroup] getProxyNode] AsOn: True];
     
     [terminalNode setPrediction: [aNode getPrediction]];
     
     // Dec 1 - note here that the terminal node being created
     // being set as the firstnode of the group.
     
     [terminalNode createGroup]; 
     
     [(TerminalNode *) terminalNode setSuspended: True];
     [(TerminalNode *) terminalNode setFired: [aNode getFired]];
     [(TerminalNode *) terminalNode setCorrect: [aNode getCorrect]];
     // April 13 2000 - change to true rather than copy
     // from passed in node
     [terminalNode setRealActive: True];
     
     [[terminalNode getGroup] setRealActive: True];
     // April 13 2000 - change to not matched rather than copy
     // from passed in node
     [[[terminalNode getGroup] getProxyNode] setMatched: False];
     
     // Dec 1 - removed this as terminal proxy had 2 inputs.
     // decided it was better to base inputs on 
     // The terminal groups proxy node input comes from this group.
     //       [[[terminalNode getGroup] getProxyNode] addInput: 
     //       [[[aNode getInputList] getLast] getNode] AsOn: True];
     
     // April 13 - changed to add to proxy not node
     [[[[[[aNode getInputList] getLast] getNode] getGroup] getProxyNode]
       addSuspendedOwner: terminalNode];
     
     [(TerminalNode *) terminalNode setSupported: 
			 [(PredictorNode *) aNode getSupported]];
     
     [agentModel addNode: terminalNode];
     
     // Note: we are adding to the list while traversing it, however, 
     // this will be placed last
     
     [[aNode getPrediction] addPredictor: terminalNode];
     
     // supress your inputs so they are not used in other ANDS
     // as a duplicate of your self. ??
     
     //     [[terminalNode getGroup] checkTemporalSupress];
     
     // Finally set the terminal node to be the proxyNode of the terminal
     // group created by the terminal node just above:
     
     terminalNode = [[terminalNode getGroup] getProxyNode];
     [(TerminalGroup *) [terminalNode getGroup] setTopGroup: self];
     [(TerminalGroup *) [terminalNode getGroup] setTemporalGroup: self];
     [self setTerminalGroup: [terminalNode getGroup]];
     if ([agentModel getDebug])
       fprintf(stdout,"\n First temporal node %ld topGroup is to: %ld, \n terminalGroup: %ld",
	       nodeNumber, [[self getTopGroup] getNodeNumber], 
	       [terminalGroup getNodeNumber]);
   }
   
   if ([agentModel getDebug])
     fprintf(stdout, "\n finished nodeGroup createGroup");
   
   // NB: the inputs for proxies are now added when the group is created
   // in Node.m
   
   return self;
}


-createNaryProxy: (id) aNode
{
  proxyNode = [NaryNode createBegin: [self getZone]];
  [proxyNode setModel: agentModel];
  [proxyNode setType: [(NaryNode *) aNode getType]];
  // 0 is AND
  [proxyNode setNodeNumber: nodeNumber];      // this groups number  
  proxyNode = [proxyNode createEnd]; 
  
  [proxyNode buildObjects];
  [proxyNode setProxyGroup: self];
  
  // NB: the inputs for proxies are now added when the group is created
  // in Node.m
  
  return self;
}


-createTerminalProxy: (id) aNode
{
  proxyNode = [TerminalNode createBegin: [self getZone]];
  [proxyNode setModel: agentModel];
  [proxyNode setType: [(NaryNode *) aNode getType]];
  // 0 is AND
  [proxyNode setNodeNumber: nodeNumber];      // this groups number  
  proxyNode = [proxyNode createEnd]; 
  
  [proxyNode buildObjects];
  [proxyNode setProxyGroup: self];
  
  // NB: the inputs for proxies are now added when the group is created
  // in Node.m
  
  return self;
}

-movePredictors: (id) aNode
{
  
  // move the predictors of the node to predict this group.
  
  int index, count;
  id predictor;
  id tempList;
  
  tempList = [[aNode getPredictorList] copy: [self getZone]];
  count = [tempList getCount];
  
  for (index=0; index < count;index++)
    {
      predictor = [tempList atOffset: index];
      [proxyNode addPredictor: predictor]; 
      [aNode removePredictor: predictor];
      [predictor setPrediction: self];
    }
  
  return self;
  
}

-(long) getNodeNumber
{
  return nodeNumber;
}

-addNode: (id) aNode
{
// set copy tells the node it has no inputs, so dont checkInputs

  if (firstNode == nil)
    firstNode = aNode;
  else   
    [aNode setCopy];   
  
  [nodeList addLast: aNode];
  
  // Took this out as all nodes are predicted by just their group
  //     [self movePredictors: aNode]; 
  [aNode addPredictor: self];
  
  return self;
}

-removeSelf: (id) aNode
{
  
  // this piece of code is for temporal nodes.
  // Once a node in chain of temporal nodes falls
  // below a threshold strength value, the entire chain is 
  // removed, including the other temporal nodes in the chain. 

  
  // The first node's input should be the firstnode of the
  // previous temporal group in the chain. Don't remove 
  // groups, if they are Nary, as this is the end of the chain.
  // In this case just remove the terminal group
  
  if (removed == True)
    return self;

  removed = True;
   
   if ([proxyNode respondsTo: M(isTemporal)]) {
     if ([[[[firstNode getInputList] 
	     getLast] getNode] respondsTo: M(isTemporal)])
       {
	 [(NodeGroup *) [[[[firstNode getInputList] getLast] getNode] 
			  getGroup] removeSelf: nil];
       }
     else
       [(NodeGroup *) [terminalNode getGroup] removeSelf: nil];
   }
   
   // This will remove all the nodes in the group.

   [proxyNode removeSelf: nil];
   
   [self removeNode: nil];

   [(AgentModelSwarm *) agentModel removeNode: self];
   [[agentModel getDropList] addLast: self];
   
   if ([agentModel getDebug]) {
     printf("\n added group to droplist: %ld", nodeNumber);
   }
   
   return self;
}

// This is for temporal nodes at end of chain only. These nodes do 
// not remove the entire chain, they remove themselves and reset the
// previous group as topGroup

-removeTemporal {

  int count;

  if ([agentModel getDebug])
    printf("\n removing nodegroup: %ld at the end of the chain", nodeNumber);

  if ([[[[firstNode getInputList] 
	  getLast] getNode] respondsTo: M(isTemporal)])
    {
      // Set previous node in chain as topGroup
      [(TerminalGroup *) [self getTerminalGroup] 
	setTopGroup: [[[[firstNode getInputList] getLast] getNode] getGroup]];
      // Oct 5 2000 - remove previous nodes in new top group
      [[[[[[firstNode getInputList] getLast] getNode] getGroup] 
	getPreviousNodeList] removeAll]; 
   }
  else {
    if ([agentModel getDebug])
      printf("\n not removing, first extension in chain");
    // you are first node in the chain 
    //(your last input must be a terminal node)
    // return, as you need not be removed
    return self;
  }  
  
  [(AgentModelSwarm *) agentModel removeNode: self];

  [[agentModel getDropList] addLast: self];
  
      // add self to agentModel dropList
  if ([agentModel getDebug]) {
    printf("\n Added group to droplist: %ld", nodeNumber);
  }
      
  // prevent NodeGroup:remove being called by nodes removing themselves.

  removed = True;

  if ([nodeList getCount] > 0) 
    {
      count = [nodeList getCount];
      while (count > 0) {
	count--;
	// [agentModel removeFromList: [nodeList atOffset: count]];
	[[nodeList atOffset: count] temporalRemoveSelf: nil];
      }  
    }

  if ([agentModel getDebug]) 
    printf("\n ============== Removed nodes from group %ld", nodeNumber);  
  
  [proxyNode temporalRemoveSelf: nil];
      
  return self;
}

// aNode of nil will remove all nodes in group
-removeNode: aNode
{
  id tempList;

  // Something is wrong with this, when I take out the first node stuff,
  // first be careful to replace the firstnode with another node
   
  if ([agentModel getDebug]) {
    printf("\n ============== Removing node from group %ld group is temporal: %d, terminal: %d, unary: %d", nodeNumber, [self respondsTo: M(isTemporal)],  
	   [self respondsTo: M(isTerminal)],  
	   [self respondsTo: M(isUnary)]);
  }


  if ([agentModel getDebug]) {
    if (aNode == nil)
      printf("\nnodeList count: %d, node is NULL", [nodeList getCount]); 
    else
      printf("\nnodeList count: %d, node is %ld", [nodeList getCount], 
	     [aNode getNodeNumber]); 
  }
  
  if (([nodeList getCount] == 1) ||
      // If it is an Nary node, and the first node, remove entire group 
      (![proxyNode respondsTo: M(isTemporal)] &&
       ![proxyNode respondsTo: M(isTerminal)] &&
       (aNode == firstNode)))
    {

      if ([agentModel getDebug]) {
      	printf("\n removing group %ld because only one node", nodeNumber);
      }

      if ([nodeList getCount] > 0) 
        {
	  tempList = [nodeList copy: [self getZone]];
	  // Feb 25 - do this first

	  [nodeList removeAll];

	  [tempList forEach: M(removeSelf:) : (id) self];
	  [tempList drop];
        }
  
	if ([agentModel getDebug]) {
	  printf("\n removed all nodes");
	  //  [self printOn];
	}
    
      [self remove];
      
      if ([agentModel getDebug]) 
	printf("\n ============== Removed nodegroup %ld", nodeNumber);  
    }  
  else {
    // May 31 2002 - if first temporal node is removed  remove entire group.

    if (([nodeList getCount] <= 1) || (aNode == nil)
	|| ([proxyNode respondsTo: M(isTemporal)] &&
	    (aNode == firstNode)))
      {

	if ([agentModel getDebug]) {
	  printf("\n removing group because node is nil");
	  //  [self printOn];
	}

	[firstNode removeSelf: self];
	if ([nodeList getCount] > 0) 
	  {
	    tempList = [nodeList copy: [self getZone]];
	    // Feb 25 - do this first
	    
	    [nodeList removeAll];
	    
	    [tempList forEach: M(removeSelf:) : (id) self];
	    [tempList drop];
	  }
	if (![proxyNode respondsTo: M(isTemporal)])
	  [self remove];
	
	if ([agentModel getDebug]) 
	  printf("\n ============== Removed nodes from group %ld", nodeNumber);  	
	[proxyNode removeSelf: nil];
      }
    else
      {
	// replace first node with another node for new copies
	
	if ([agentModel getDebug]) 
	  printf("\n ============== Removing first node from group %ld", nodeNumber);  
	
	//	if ([aNode getNodeNumber] == 823) {
	//  printf("\n Remove 4, time: %d", getCurrentTime());
	//	}

	if (aNode == firstNode)
	  firstNode = [nodeList atOffset: 1];
	
	if ([nodeList contains: aNode])      
	  [nodeList remove: aNode];
      }
  }
  return self;
}

-remove
{

  if ([agentModel getDebug]) {
    printf("\n in remove for group");
  }

  if (!removed)
    {

      removed = True;

      [agentModel removeGroup];

      if ([proxyNode respondsTo: M(isTemporal)]) {
	if ([[[[firstNode getInputList] 
		getLast] getNode] respondsTo: M(isTemporal)])
	  {
	    [(NodeGroup *) [[[[firstNode getInputList] getLast] getNode] 
			     getGroup] removeSelf: nil];
	  }
	else
	  [(NodeGroup *) [terminalNode getGroup] removeSelf: nil];
      }

      [(AgentModelSwarm *) agentModel removeNode: self];
      [[agentModel getDropList] addLast: self];
      
      // add self to agentModel dropList
      if ([agentModel getDebug]) {
	printf("\n Added group to droplist: %ld", nodeNumber);
      }
      
      [(NaryNode *) proxyNode removeSelf: self];

      if (terminalNode != nil)
	[[terminalNode getGroup] removeSelf: nil];
    }
  
  return self;
}

// Returns maximum dependent value for nodes in group
// Oct 12 - 2000 added specificity
// Nov 14 - 2000 removed specificity

-(double) getDependentReturn 
{
  double maxQ = 0;
  id aNode = nil;
  
  int count = [nodeList getCount];
  while (count > 0) {
    count --;
    aNode = [nodeList atOffset: count];
    if (([aNode getAbsDependentValue]
	 > maxQ)
	&& ![aNode getTemporallySuspended])
      maxQ = [aNode getAbsDependentValue];
  }
  
  return maxQ;
}

// Returns maximum ACTUAL dependent value for nodes in group
// Oct 12 2000 - added specificity
// Nov 14 2000 - removed specificity

-(double) getActualDependentReturn 
{
  double maxQ = -10000;
  id aNode = nil; 
  
  int count = [nodeList getCount];

  if (count == 0)
    return 0;

  while (count > 0) {
    count --;
    aNode  = [nodeList atOffset: count];
    if (([aNode getDependentValue]
	 > maxQ)
	&& ![aNode getTemporallySuspended])
      maxQ = [aNode getDependentValue];
  }
  
  return maxQ;
}


// Returns maximum INdependent value for nodes in group
// Oct 12 2000 - added specificity
// Nov 14 2000 - removed specificity

-(double) getActualIndependentReturn 
{
  double maxQ = -10000;
  id aNode = nil; 
  
  int count = [nodeList getCount];

  if (count == 0)
    return 0;

  while (count > 0) {
    count --;
    aNode  = [nodeList atOffset: count];
    if (([aNode getIndependentValue]
	 > maxQ)
	&& ![aNode getTemporallySuspended])
      maxQ = [aNode getIndependentValue];
  }
  
  return maxQ;
}


// Returns max ABS independent return
// Oct 5 2000 - include specificity in result.

-(double) getIndependentReturn 
{
  double maxQ = 0;
  id aNode = nil;
  //  double threshold = [agentModel getActivationThreshold];

  int count = [nodeList getCount];

  if ([agentModel getDebug])
    printf("\n getIndependentReturn called for group: %ld", nodeNumber);

  while (count > 0) {
    count --;
    aNode = [nodeList atOffset: count];
    if (([aNode getAbsIndependentValue]
	 > maxQ))
	//	&& ![aNode getTemporallySuspended]
	// Sept 21 2000 - only return those nodes which
	// exceed activation count (primarily for terminal remove)
	//	&& ([aNode getActivationCount] > threshold)) 
      {
	if ([agentModel getDebug])
	  printf("\n getIndependentReturn max node accuracy: %f",
		 [aNode getAbsIndependentValue]);
	maxQ = [aNode getAbsIndependentValue]; 
      }
  }
  
  return maxQ;
}

// Applies to temporal groups only, returns the maximum discounted
// terminal value for comparison with the extendThreshold

// June 13 2002 - search for highest Abs value but return actual value.

-(double) getMaxTerminalValue 
{
  double maxQ = -10000;
  double realQ = -10000;
  
  int count = [nodeList getCount];
  while (count > 0) {
    count --;
    if ([(TemporalNode *) [nodeList atOffset: count] 
			  getAbsDiscountedTerminalValue] > maxQ) {
	maxQ = [(TemporalNode *) [nodeList atOffset: count]
				 getAbsDiscountedTerminalValue];
	realQ =  [(TemporalNode *) [nodeList atOffset: count]
				 getDiscountedTerminalValue];
    }
  }
  return realQ;
}

// Returns maximum INdependent ACCURACY for nodes in group

-(double) getIndependentAccuracy
{
  double maxQ = -10000;
  
  int count = [nodeList getCount];
  while (count > 0) {
    count --;
    if (([[nodeList atOffset: count] getIndependentAccuracy] > maxQ)
	&& ![[nodeList atOffset: count] getTemporallySuspended])
      maxQ = [[nodeList atOffset: count] getIndependentAccuracy];
  }
  
  return maxQ;
}

// This ensures that only nodes with the same prediction can be used in 
// comparison with higher terminal modes. 

-setReturnStrength: (double *) aReturn
{
  // Just in case you receive a negative value.

  if ((*aReturn < 0.0) && (Qreturn == 0.0))
     Qreturn = -10000;

  if (*aReturn > Qreturn) {
    if ([agentModel getDebug])
      fprintf(stdout,"\n Group: %ld setting return strength: %f", nodeNumber, *aReturn);
    Qreturn = *aReturn;
  }
     return self;
}

-(double) getQreturn
{
  return Qreturn;
}

-updateAverageReturn
{

  // Feb 21 2001 - only update for temporal groups if terminal group
  // is realActive.
  if ([proxyNode respondsTo: M(isTemporal)])
    {
	if ([firstNode getTemporallyFired]) {
	  if ([agentModel getDebug])
	    printf("\n Temporal Group: %ld, Average return: %f, Qreturn: %f",
		   nodeNumber, averageReturn, Qreturn);
	  averageReturn = averageReturn + [agentModel getLearningRate] *
	    (Qreturn - averageReturn);
	}
    }
  else
    {
      if (matched) { 
	if ([agentModel getDebug])
	  printf("\n Node Group: %ld, Average return: %f, Qreturn: %f",
		 nodeNumber, averageReturn, Qreturn);

	averageReturn = averageReturn + [agentModel getLearningRate] *
	  (Qreturn - averageReturn);
      }
    }
 
  return self;
}

// This is used for temporal nodes to pay previous nodes

-setTemporalReturnStrength: (double *) aReturn
{
  // Just in case you receive a negative value.

  if ((*aReturn < 0) && (temporalQreturn == 0))
     temporalQreturn = -10000;

  if (*aReturn > temporalQreturn) {
    if ([agentModel getDebug])
      fprintf(stdout,"\n setting temporal return strength: %f", *aReturn);
    temporalQreturn = *aReturn;
  }
     return self;
}



-hypSetReturnStrength: (double *) aReturn
{
     if (*aReturn > hypQreturn)
         hypQreturn = *aReturn;
     return self;
}


-payPredictors
{
  // this is different from pay below, which passes node
  // payments to other nodes, this passes rewards to predictor nodes
  int predictors = 0;
  
  double paymentEach;
  
  // replaced comment code below with this

  // Feb 21 2001 - apart from top final groups, 
  // temporal nodes only pay predictors once the terminal group's
  // firstNode is realactive
 
  /*
  if ([proxyNode respondsTo: M(isTemporal)]) {
    if (topGroup && finalGroup) {
      if (![proxyNode getFirstInputMatchedNow])
	return self; 
    }
    else {
      if (![[self getTerminalGroup] getRealActive]
	// Mar 14 2002 - commented out following to allow
	// for rewards to be sent each time regardless of correctness
      	  || ![[[self getTerminalGroup] getFirstNode] getCorrect])
	return self;
    }
  }
  */

  if ([agentModel getDebug])
    fprintf(stdout, "\n NodeGroup: %ld paying predictors, matched: %d,\n activeSupressed %d, aTS: %d Strength: %f", 
	    nodeNumber, matched, activeSupressed,
	    activeTemporallySupressed, strength);
  
  if ([proxyNode respondsTo: M(isTemporal)]) {
    if (![self isTopGroup])
      predictors = [[self getPreviousNodeList] getCount];
    else
      if (finalGroup)
	predictors = [[self getActivePredictorList] getCount]
	  +  [[self getSuspendedPredictorList] getCount]
	  +   [[self getPassivePredictorList] getCount];
    // you are the group with a terminal node and must pay your own nodes
    if 	([self getTerminalNode] != nil)
      predictors = predictors + [nodeList getCount];
  }
  else
    predictors = [[self getActivePredictorList] getCount]
      +  [[self getSuspendedPredictorList] getCount]
      +  [[self getPassivePredictorList] getCount];
  
  
   if (predictors > 0)
     {
       paymentEach = strength; 
       [self pay: &paymentEach]; // Note: temporal nodes must be excluded
       // as their payments come from the terminal node as returns. 
       // they are excluded in the overridden pay.
     } 
  
   strength = 0;
   
   return self;
}

-sendPredictorsReturn
{
  // this is different from pay below, which passes node
   // payments to other nodes, this passes rewards to predictor nodes
  
  int predictors = 0;
  double paymentEach;
  
  if ([proxyNode respondsTo: M(isTemporal)]) {
    // July 15 2002 - allow all nodes to send support once chain is final
    // not just top group:
    if (![[self getTopGroup] getFinalGroup]) 
      return self;
  } else   // July 4 2002 added following:
    if (suspended)
      return self;

  // July 15 2002 - don't send returns if zero:

  if (Qreturn == 0)
    return self;
  
  // Dec 5 If we are not matched, send zero return 
  // Note I have removed the condition that we are not active supressed
  // in any way, as a general rule should reflect the general
  // strength given each specific rule. 

  if (!(matched 
	|| ([proxyNode respondsTo: M(isTemporal)]
	    //	    && topGroup && finalGroup 
	    && [proxyNode getFirstInputMatchedNow])))
    return self;

  // July 4 2002 - changed following to above:
  // Qreturn = 0;

  // June 17 2002 - if activeSupressed payement is zero
  // don't so this in pay predictors, they shoudl still get reward.

  // July 4 2002 - added activeTemporallySupressed
  if (activeSupressed || activeTemporallySupressed)
    return self;
  
  predictors = [[self getActivePredictorList] getCount]
    +  [[self getSuspendedPredictorList] getCount]
    +  [[self getPassivePredictorList] getCount];
  
  if ([agentModel getDebug])
      printf("\n node group %ld payingPredictorsReturn: %f, predictors: %d",
	     nodeNumber, Qreturn, predictors);
  
  if (predictors > 0)
    {
      // April 15 2002 - changed following:
      paymentEach = Qreturn;
      // paymentEach = [agentModel getQreturn]; 

      // If the problem terminates on receiving a reward, Don't pay returns 
      // and rewards at same time -  May 15 2000
      // Must still send returns for temporal threshold though

      //      if ([agentModel getFiniteProblem] && [agentModel getEndOfTrial])
      //	paymentEach = 0;
      [self payReturn: &paymentEach];
    }

  //  Qreturn = 0;

  return self;
}

-sendPreviousReturn
{
  // Send payments to previous nodes in temporal chain.
  // Applies only to Temporal Groups (determined by proxynode type) 
  // Exclude top nodes as they have no previous 
  
  int predictors = 0;
  double paymentEach;
  
  if (![proxyNode respondsTo: M(isTemporal)]) 
    return self;
  
  if (topGroup) 
    return self;

  // Feb 21 2001 - removed following
  //  if (!(matched || [proxyNode getFirstInputMatchedNow]))
  // Qreturn =0;

  // Feb 21 2001 - added folowing, don't do updates unless
  // terminal node has fired

  // April 17 - changed following 
  // if (![[self getTerminalGroup] getRealActive])
  //  return self;

  // if terminal node is not correct, everything updates with zero.
  //  if (![[[self getTerminalGroup] getFirstNode] getCorrect])
  //  Qreturn = 0;

  if ([agentModel getDebug])
    printf("\n node group %ld about to send previous return, matched: %d, \n activeSupressed: %d, activeTemporallySupressed: %d", nodeNumber,
	   [self getMatched], activeSupressed, activeTemporallySupressed); 
  
      predictors = [[self getPreviousNodeList] getCount];
 
      if ([agentModel getDebug])
	printf("\n node group %ld sending previous return: %f, \n predictors: %d", nodeNumber, Qreturn, predictors);
      
      if (predictors > 0) {
	paymentEach = Qreturn;
	// If the problem terminates on receiving a reward, Don't pay returns 
	// and rewards at same time -  May 15 2000
	// Must still send returns for temporal threshold though
	if ([agentModel getFiniteProblem] && [agentModel getReward] != 0)
	  paymentEach = 0;
	
	[self payPreviousReturn: &paymentEach];
      }

  Qreturn = 0;
  
  return self;
}

// This is a bit messy, first sendTemporalReturn is sent to 
// terminal groups, then it is sent again to all groups,
// but is intended really for only temporal groups
// terminal groups will respond again, but 
// don't need to.
// sendTemporalReturn is implemented slightly differently
// for Terminal groups (in TerminalGroup).
 
-sendTemporalReturn
{
  // Send payments to previous nodes in temporal chain.
  // Applies only to Temporal Groups (determined by proxynode type) 
  // Exclude top nodes as they have no previous 
  
  int predictors = 0;
  double paymentEach;
  double groupReturn = 0;
  

  if (!matched) 
    return self;

  if (![proxyNode respondsTo: M(isTemporal)]) 
    return self;
  
  if (topGroup) 
    return self;
  
  if ([agentModel getDebug])
    printf("\n node group %ld about to send temporal return, matched: %d, \n activeSupressed: %d, activeTemporallySupressed: %d", nodeNumber,
	   [self getMatched], activeSupressed, activeTemporallySupressed); 

  // Nov 23 2000 - return the value of higher temporal nodes if their
  // are any and they have a higher value.
  
  // July 2 2002 - removed following:
  // if (terminalNode != nil)
  //   groupReturn = [[terminalNode getGroup] getGroupDependentReturn];
  // if (groupReturn > temporalQreturn)
  //    temporalQreturn = groupReturn;
  
  predictors = [[self getPreviousNodeList] getCount];
 
   if ([agentModel getDebug])
    printf("\n node group %ld sending temporal return: %f, \n predictors: %d", nodeNumber, temporalQreturn, predictors);
  
  if (predictors > 0) {
    paymentEach = temporalQreturn;
    [self payTemporalPreviousReturn: &paymentEach];
  }

  temporalQreturn = 0;
  
  return self;
}

-hypPayPredictors
{
  // this is different from pay below, which passes node
  // payments to other nodes, this passes rewards to predictor nodes
  int predictors = 0;
  
  double paymentEach;
  
  if (((hypMatched && !hypActiveSupressed) || hypActivePredicted
       || hypSuspendedPredicted) && (!hypActive))
    {
      predictors = [[self getHypActivePredictorList] getCount]
	+  [[self getHypSuspendedPredictorList] getCount];
      
      if (predictors > 0)
	{
	  [self hypPay: &paymentEach];
	  hypStrength = 0;
	}  
    }
   return self;
}


-hypSendPredictorsReturn
{
  // this is different from pay below, which passes node 
  // payments to other nodes, this passes rewards to predictor nodes
  int predictors = 0;
  
  double paymentEach;
  
  if (!matched || activeSupressed || (realActive && !lastActiveSupressed))
    return self;
  
  if ([agentModel getDebug])
    printf("\n node group %ld paying hyp return: %f", nodeNumber, hypQreturn);
  
  predictors = [[self getActivePredictorList] getCount]
    +  [[self getSuspendedPredictorList] getCount];
  
  if (predictors > 0)
    {
      paymentEach = hypQreturn; 
      [self hypPayReturn: &paymentEach];
    } 
  hypQreturn = 0;
  
  return self;
}

-pay: (double *) paymentEach
{

// This receives the payments from a node in the group and redistributes 
// it across the real predictors of the node.
// Note: this will be called a number of times as the nodes in the group
//       pass back the pay message.

  if ([agentModel getDebug]) {
    printf("\n In pay for group: %ld", nodeNumber);
  }

  if ([proxyNode respondsTo: M(isTemporal)]) {
    if (![self isTopGroup]) {
      [[self getPreviousNodeList] forEach: M(pay:) 
				  : (void *) paymentEach];
    }
    else
      if (finalGroup) {
	if ([[self getActivePredictorList] getCount] > 0)
	  [[self getActivePredictorList] forEach: M(pay:) 
					 : (void *) paymentEach];
	if ([[self getSuspendedPredictorList] getCount] > 0)
	  [[self getSuspendedPredictorList] forEach: M(pay:) 
					    : (void *) paymentEach];
	if ([[self getPassivePredictorList] getCount] > 0) 
	  [[self getPassivePredictorList] forEach: M(pay:) 
					  : (void *) paymentEach];
      }
    // If terminal node group, must pay nodes yourself
    if ([self getTerminalNode] != nil)
      if ([[self getNodeList] getCount] > 0)
	[[self getNodeList] forEach: M(pay:) 
			    : (void *) paymentEach];
  }
  else {
    if ([[self getActivePredictorList] getCount] > 0)
      [[self getActivePredictorList] forEach: M(pay:) 
				     : (void *) paymentEach];
    if ([[self getSuspendedPredictorList] getCount] > 0)
      [[self getSuspendedPredictorList] forEach: M(pay:) 
					: (void *) paymentEach];  
    if ([[self getPassivePredictorList] getCount] > 0)
      [[self getPassivePredictorList] forEach: M(pay:) 
				      : (void *) paymentEach];
  }
  return self;
}

// This will check that a node sending support has the maximum
// strength for a group. If it doesn't it will allow another node
// to send support instead, but will still act as though it really
// did send support (prevents multiple nodes sending support
// effectively doubling (in some cases) the support sent).

- (boolean) maxStrengthForEffector: (id) aNode
{
  int count = [nodeList getCount];
  
  while (count > 0) {
    count--;
    if ([nodeList atOffset: count] != aNode)
      if ([(PredictorNode *) [nodeList atOffset: count] getSupported] 
	  == [(PredictorNode *) aNode getSupported])
	if ([[nodeList atOffset: count] getDependentValue] 
	    > [aNode getDependentValue])
	  return False;
  }
  return True;
}


-payReturn: (double *) paymentEach
{

// This receives the payments from a node in the group and redistributes 
// it across the real predictors of the node.
// Note: this will be called a number of times as the nodes in the group
//       pass back the pay message.
 
   if ([[self getActivePredictorList] getCount] > 0)
       [[self getActivePredictorList] forEach: M(payReturn:) 
                                 : (void *) paymentEach];
   if ([[self getSuspendedPredictorList] getCount] > 0)
       [[self getSuspendedPredictorList] forEach: M(payReturn:) 
                                 : (void *) paymentEach];
   if ([[self getPassivePredictorList] getCount] > 0)
     [[self getPassivePredictorList] forEach: M(payReturn:) 
				     : (void *) paymentEach];
   return self;
}

-payPreviousReturn: (double *) paymentEach
{

// This receives the payments from a node in the group and redistributes 
// it across the real predictors of the node.
// Note: this will be called a number of times as the nodes in the group
  //       pass back the pay message.
  
  if ([self getPreviousNodeList] == nil)
    {
      printf("\nWARNING: Previous node list nil for group: %ld", nodeNumber);
      return self;
    } 
  
  if ([[self getPreviousNodeList] getCount] > 0)
    [[self getPreviousNodeList] forEach: M(payReturn:) 
				: (void *) paymentEach];
  else
    if ([agentModel getDebug])
      fprintf(stdout, "\n previous node list for group: %ld is empty",
	      nodeNumber);
  
  return self;
}


-payTemporalPreviousReturn: (double *) paymentEach
{

  // This makes payments of discountedTerminalValues to
  // previous link in chain, work same as payPreviousReturn, but is
  // updating dicountedTerminalValue in previous node, rather than
  // the other values.
  
  if ([self getPreviousNodeList] == nil)
    {
      printf("\nWARNING: Previous node list nil for group: %ld", nodeNumber);
      return self;
    } 

  if ([agentModel getDebug]) {
    printf("\n Group %ld payingTemporalPreviousReturn", nodeNumber);
    fflush(stdout);
  }
  
  if ([[self getPreviousNodeList] getCount] > 0)
    [[self getPreviousNodeList] forEach: M(payTemporalReturn:) 
				: (void *) paymentEach];
  else
    if ([agentModel getDebug])
      fprintf(stdout, "\n previous node list for group: %ld is empty",
	      nodeNumber);
  
  return self;
}

-hypPay: (double *) paymentEach
{
  
  // This receives the payments from a node in the group and redistributes 
  // it across the real predictors of the node.
  // Note: this will be called a number of times as the nodes in the group
  // pass back the pay message.
  
  if ([[self getHypActivePredictorList] getCount] > 0)
    [[self getHypActivePredictorList] forEach: M(hypPay:) 
				      : (void *) paymentEach];
  if ([[self getHypSuspendedPredictorList] getCount] > 0)
    [[self getHypSuspendedPredictorList] forEach: M(hypPay:) 
					 : (void *) paymentEach];
  
  return self;
}


-hypPayReturn: (double *) paymentEach
{
  
  // This receives the payments from a node in the group and redistributes 
  // it across the real predictors of the node.
  // Note: this will be called a number of times as the nodes in the group
  // pass back the pay message.
  
  if ([[self getActivePredictorList] getCount] > 0)
    [[self getActivePredictorList] forEach: M(hypPayReturn:) 
				   : (void *) paymentEach];
  if ([[self getSuspendedPredictorList] getCount] > 0)
    [[self getSuspendedPredictorList] forEach: M(hypPayReturn:) 
				      : (void *) paymentEach];
  
  return self;
}


-(boolean) activePredictedBy: (id) aNode
{
  // Forward the message to all nodes, as they all have the 
  // same inputs anyway. This is what a group is really for.
  // If the node is already predicted by the group, don't
  // predict it again
  
  [proxyNode activePredictedBy: aNode];
  
  if (!activePredicted)
    [nodeList forEach: M(activePredictedBy:) :(id) self];
  
  activePredicted = True;
  return True;
}


-(boolean) hypActivePredictedBy: (id) aNode
{
  // Forward the message to all nodes, as they all have the 
  // same inputs anyway. This is what a group is really for.
  // If the node is already predicted by the group, don't
  // predict it again
  
  [proxyNode hypActivePredictedBy: aNode];
  
  if (!hypActivePredicted)
    [nodeList forEach: M(hypActivePredictedBy:) :(id) self];
  
  hypActivePredicted = True;
  return True;
}


-(boolean) passivePredictedBy: (id) aNode
{
  // Forward the message to all nodes, as they all have the 
  // same inputs anyway. This is what a group is really for.
  // If the node is already predicted by the group, don't
  // predict it again
  
  [proxyNode passivePredictedBy: aNode];
  if (!passivePredicted)
    [nodeList forEach: M(passivePredictedBy:) :(id) self];
  
  passivePredicted = True;
  
  return True;
}


-(boolean) hypPassivePredictedBy: (id) aNode
{
  // Forward the message to all nodes, as they all have the 
  // same inputs anyway. This is what a group is really for.
  // If the node is already predicted by the group, don't
  // predict it again
  
  [proxyNode hypPassivePredictedBy: aNode];
  if (!hypPassivePredicted)
    [nodeList forEach: M(hypPassivePredictedBy:) :(id) self];
  
  hypPassivePredicted = True;
  
  return True;
}



-(boolean) suspendedPredictedBy: (id) aNode
{
  // Forward the message to all nodes, as they all have the 
  // same inputs anyway. This is what a group is really for.
  // If the node is already predicted by the group, don't
  // predict it again
  
  [proxyNode suspendedPredictedBy: aNode];
  if (!suspendedPredicted) 
    [nodeList forEach: M(suspendedPredictedBy:) :(id) self];
  
  suspendedPredicted = True;
  
  return True;
}



-(boolean) hypSuspendedPredictedBy: (id) aNode
{
  // Forward the message to all nodes, as they all have the 
  // same inputs anyway. This is what a group is really for.
  // If the node is already predicted by the group, don't
  // predict it again
  
  [proxyNode hypSuspendedPredictedBy: aNode];
  if (!hypSuspendedPredicted) 
    [nodeList forEach: M(hypSuspendedPredictedBy:) :(id) self];
  
  hypSuspendedPredicted = True;
  
  return True;
}

-(boolean) addPredictor: (id) aNode
{
  [proxyNode addPredictor: aNode];
  return True;
}

-(boolean) removePredictor: (id) aNode
{
  if ([aNode respondsTo: M(isTerminal)]) {
    if (interest > 1.0)
      interest = interest - 1.0;
  }

  [proxyNode removePredictor: aNode];
  return True;
}

-addToRewardList: (id) aNode
{
  [rewardList addLast: aNode];
  return self;
}

-clearRewardList
{
  [rewardList removeAll];
  return self;
}

-addActiveOwner: (id) anOwner
{
  [activeOwnerList addLast: anOwner];
  return self;
}

-addSuspendedOwner: (id) anOwner
{
  [suspendedOwnerList addLast: anOwner];
  return self;
}

-addActiveOwners: (id) aList
{
  activeOwnerList = [aList copy: [self getZone]];
  return self;
}

-addSuspendedOwners: (id) aList
{
  suspendedOwnerList = [aList copy: [self getZone]];
  return self;
}

-removeActiveOwner: (id) aNode
{
  [activeOwnerList remove: aNode];
  return self;
}

-removeSuspendedOwner: (id) aNode
{
  [suspendedOwnerList remove: aNode];
  return self;
}

-addPreviousNode: (Node *) aNode
{
  if (aNode == nil)
    return self;
  
  // owners are initially added as active 
  // this allows them to influence system behaviour
  
  if ([agentModel getDebug])
    fprintf(stdout, "\n NodeGroup %ld adding previous node: %ld",
	    nodeNumber, [aNode getNodeNumber]);
  
  [[self getPreviousNodeList] addLast: aNode];
  return self;
}

-(boolean) getUpdateTemporalSupressed
{
  return updateTemporalSupressed;
}

-checkActiveSupress
{

  // June 18 2002 Let terminal groups active supress inputs

  if ([proxyNode respondsTo: M(isTemporal)])
      //  || [proxyNode respondsTo: M(isTerminal)])
    return self;
  else
    [proxyNode checkActiveSupress];
  
  return self;
}

-checkActiveActionSupress
{

  //  if  ([proxyNode respondsTo: M(isTerminal)])
  [proxyNode checkActiveActionSupress];
  
  return self;
}

-checkHypActiveSupress
{
  [proxyNode checkHypActiveSupress];
  return self;
}

-checkNarySupress
{

  // June 18 2002 - only nary groups do this

  // July 16 2002 - dont nary supress under temporal nodes:

  if (![proxyNode respondsTo: M(isTemporal)])
  //     && ![proxyNode respondsTo: M(isTerminal)])
    [proxyNode checkNarySupress];
  
  return self;
}


// April 11 2001 - 

-checkExclude
{
  int index = 0;

  // Aug 17 2023 - replaced line below as unary nodes were not being excluded properly:
  // if (![proxyNode respondsTo: M(isTemporal)]) { 

  if (![proxyNode respondsTo: M(isTemporal)] && ![proxyNode respondsTo: M(isNary)]) { 
    index = [uniformIntRand getIntegerWithMin: 0 
			     withMax: [agentModel getNarySupressionRate]];
    if (index == 1) {
      if ([agentModel getDebug])
	printf("\n Excluding group: %ld", nodeNumber); 
      [proxyNode exclude];
    }
  }
  return self;
}

-checkSupress
{
  if ([agentModel getDebug])
    printf("\n Node group : %ld received checkSupress, realActive: %d",
	   nodeNumber, realActive);
  [proxyNode checkSupress];
  
  return self;
}

-checkTemporalSupress
{

  // For teminalGroups, temporallySupress when realActive
  // For temporalGroups, temporally suppress when firstInputMatchedLast
  // Note, this has the implication that once a node is included in a 
  // temporal chain it cannot ever be used again (as temporallySupressed
  // nodes are removed from extendList.  For this reason, only topGroups
  // in non-final chains and finalGroups in final chains checkTemporalSupress

  if ([agentModel getDebug])
    printf("\n Node group : %ld received checkTemporalSupress, realActive: %d",
	   nodeNumber, realActive);
  
  if (![proxyNode respondsTo: M(isTerminal)])
    return self;
  
  [proxyNode checkTemporalSupress];
  
  return self;
}


// Terminal nodes activeSupress inputs if the chain is final
// to prevent them being combined in ANDs to predict other nodes

// Temporal nodes activeSupress inputs to prevent them copying 
// or combining other nodes to predict them

-checkActiveTemporalSupress
{

    // Jan 19 2001 - only activetemporalsupress nodes under temporal groups
  // terminal groups will active supress inputs. 
  // Active supress prevents nodes under top group of final chain
  // from copying predictors. 

  if (![proxyNode respondsTo: M(isTerminal)]
      && ![proxyNode respondsTo: M(isTemporal)])
    return self;
  
  if ([agentModel getDebug])
    printf("\n nodegroup %ld in check activeTemporalSupress 1, topGroup: %ld fineL: %d", 
	   nodeNumber, [[self getTopGroup] getNodeNumber],
	   [[self getTopGroup] getFinalGroup]);
  
  // if ([proxyNode respondsTo: M(isTerminal)])
  [proxyNode checkActiveTemporalSupress];

  return self;
}

-checkHypSupress
{
  [proxyNode checkHypSupress];
  return self;
}

-(boolean) setUpdateTemporalSupressed: (boolean) aBoolean
{

   updateTemporalSupressed = aBoolean;

   return updateTemporalSupressed;
}

-(boolean) setUpdateTemporalSupressed: (boolean) aBoolean 
				   for: (id) anEffector
{

  // a rather arbitrary decision to supress the node group and
  // proxy node if any of the nodes in the group are supressed,
  // see, narynode setsupressed.
  
  int count;
  
  updateTemporalSupressed = aBoolean;
  count = [nodeList getCount];
  
  while (count > 0)
    {
      count--;
      [[nodeList atOffset: count] setUpdateTemporalSupressed: aBoolean];
    }
  
  return updateTemporalSupressed;
}

-(boolean) setNarySupressed: (boolean) aBoolean
{
  
  // a rather arbitrary decision to supress the node group and
  // proxy node if any of the nodes in the group are supressed,
  // see, narynode setsupressed.
  
  narySupressed = aBoolean;
  
  return narySupressed;
}

-(boolean) setSupressed: (boolean) aBoolean
{
  
  // a rather arbitrary decision to supress the node group and
  // proxy node if any of the nodes in the group are supressed,
  // see, narynode setsupressed.
  
  supressed = aBoolean;
  
  return supressed;
}


-(boolean) setTemporallySupressed: (boolean) aBoolean
{
  
  int count;
  
  temporallySupressed = aBoolean;
  count = [nodeList getCount];
  
  while (count > 0)
    {
      count--;
      [[nodeList atOffset: count] setTemporallySupressed: aBoolean];
    }
  
  return temporallySupressed;
}

-(boolean) setHypSupressed: (boolean) aBoolean
{
  
  // a rather arbitrary decision to supress the node group and
  // proxy node if any of the nodes in the group are supressed,
  // see, narynode setsupressed.
  
  hypSupressed = aBoolean;
  
  return hypSupressed;
}


-(boolean) setSupressed: (boolean) aBoolean for: (id) anEffector
{
  
  int count;
  
  supressed = aBoolean;
  count = [nodeList getCount];
  
  while (count > 0)
    {
      count--;
      [[nodeList atOffset: count] setSupressed: aBoolean];
    }
  
  return supressed;
}


-(boolean) setNarySupressed: (boolean) aBoolean for: (id) anEffector
{
  
  int count;
  
  narySupressed = aBoolean;
  count = [nodeList getCount];
  
  while (count > 0)
    {
      count--;
      [[nodeList atOffset: count] setNarySupressed: aBoolean];
    }
  
  return narySupressed;
}


-(boolean) setTemporallySupressed: (boolean) aBoolean for: (id) anEffector
{
  
  int count;
  
  temporallySupressed = aBoolean;
  count = [nodeList getCount];
  
  while (count > 0)
    {
      count--;
      [[nodeList atOffset: count] setTemporallySupressed: aBoolean];
    }
  
  return temporallySupressed;
}

-(boolean) setHypSupressed: (boolean) aBoolean for: (id) anEffector
{

  int count;
  
  hypSupressed = aBoolean;
  count = [nodeList getCount];
  
  while (count > 0)
    {
       count--;
       [[nodeList atOffset: count] setHypSupressed: aBoolean];
    }
  
  return hypSupressed;
}

// 2021 - NOTE: does not use anEffector - also sent from a proxyNode 
// So what is the supported effector? Has it been set before?

-(boolean) setActiveSupressed: (boolean) aBoolean for: (id) anEffector
{
  
  int count;
  count = [nodeList getCount];
  
  while (count > 0)
    {
      count--;
      [[nodeList atOffset: count] setActiveSupressed: aBoolean];
    }
  
  return activeSupressed;
}


-(boolean) setActiveActionSupressed: (boolean) aBoolean for: (id) anEffector
{
  
  int count;
  count = [nodeList getCount];
  
  while (count > 0)
    {
      count--;
      [(Node *) [nodeList atOffset: count] setActiveActionSupressed: aBoolean
				  for: anEffector];
    }
  
  return activeActionSupressed;
}

-(boolean) setActiveTemporallySupressed: 
		 (boolean) aBoolean for: (id) anEffector 
{
  
  int count;
  
  count = [nodeList getCount];
  
  while (count > 0)
    {
      count--;
      [[nodeList atOffset: count] setActiveTemporallySupressed: aBoolean];
    }
  
   return activeTemporallySupressed;
}

-(boolean) setHypActiveSupressed: (boolean) aBoolean for: (id) anEffector
{
  int count;
  
  hypLastActiveSupressed = hypActiveSupressed;
  hypActiveSupressed = aBoolean;
  count = [nodeList getCount];
  
  while (count > 0)
    {
      count--;
      [[nodeList atOffset: count] setHypActiveSupressed: aBoolean];
    }
  
  return hypActiveSupressed;
}

-(boolean) removeOwner: (Node *) aNode
{
  
  // The if statement is neccesary as certain conditions in removing
  // owners (i.e if you send a message to your owner to removeitself
  // after you have already removed yourself  
  
  if ([suspendedOwnerList contains: aNode])
    [suspendedOwnerList remove: aNode];
  if ([activeOwnerList contains: aNode]) 
    [activeOwnerList remove: aNode];
  
  return True;
}

-(boolean) setHypFired: (boolean) aBoolean
{
    hypFired = aBoolean;
    return hypFired;
}

// Temporal groups have a primary node which is determined the 
// first time the chain is matched and the terminal nodes prediction
// is correct.  
// Feb 21 2001

-(boolean) getPrimaryFired
{
  if (primaryNode == nil)
    return True;
  else
    if ([primaryNode getFired]) {
      return True;
    }
  return False;
}

-(boolean) getFired
{
    return fired;
}

-(boolean) getHypFired
{
    return hypFired;
}

-(boolean) getMatched
{
  return matched;
}

-(boolean) getHypMatched
{
  return hypMatched;
}

-(boolean) resetMatched: (boolean) aBoolean
{

  if ([agentModel getDebug])
    printf("\n in reset matched for group: %ld, aBoolean: %d",
	   nodeNumber,aBoolean);

  matched = aBoolean;
  [proxyNode resetMatched: aBoolean];
  return matched;    
}  

-(boolean) setMatched: (boolean) aBoolean
{
  int count;
  
  if ([agentModel getDebug])
    printf("\n in set matched for Group: %ld aBoolean: %d", 
	   nodeNumber, aBoolean);

   matched = aBoolean;    
 
   count = [nodeList getCount];
   
   while (count > 0)
     {
       count--;
       if ([nodeList atOffset: count] != proxyNode)
	 [[nodeList atOffset: count] setMatched: aBoolean];
     }
   
   // Check if you have a terminal node, if so set it to matched
   // June 22 - removed - call this directly from temporal node
   //   [self terminalNodeSetMatched: matched];
   
   // Send a temporalCorrect message to all preditors.  This is because
   // TemporalNodes do not active predict predictions, so must be 
   // notified specially so they can update correct counts.
   // if (matched)
   // [proxyNode temporalUpdate];
   
   return matched;
}


-(boolean) setHypMatched: (boolean) aBoolean
{
   int count;

   hypMatched = aBoolean;    
   
   count = [nodeList getCount];

   while (count > 0)
   {
       count--;
       [[nodeList atOffset: count] setHypMatched: aBoolean];
   }

   return hypMatched;
}

-(boolean) resetActiveSupressed: (boolean) aBoolean
{
   lastActiveSupressed = activeSupressed;
   activeSupressed = aBoolean;
   [proxyNode setActiveSupressed: aBoolean];
   return activeSupressed;
}

-(boolean) resetActiveActionSupressed: (boolean) aBoolean
{

   activeActionSupressed = aBoolean;
   [proxyNode resetActiveActionSupressed: aBoolean];
   return activeActionSupressed;
}

-(boolean) setActiveSupressed: (boolean) aBoolean
{

   activeSupressed = aBoolean;
   return activeSupressed;
}

-(boolean) resetActiveTemporallySupressed: (boolean) aBoolean 
{
 
   lastActiveTemporallySupressed = activeTemporallySupressed;
   activeTemporallySupressed = aBoolean;
   [proxyNode resetActiveTemporallySupressed: aBoolean];
   return activeTemporallySupressed;
}

-(boolean) setActiveTemporallySupressed: (boolean) aBoolean 
{
  if ([agentModel getDebug])
    printf("\n setActiveTemporalSupressed called for group: %ld,\n aBoolean: %d, activeTSupressed: %d", nodeNumber,
	   aBoolean, activeTemporallySupressed);
 
   activeTemporallySupressed = aBoolean;

   return activeTemporallySupressed;
}

-(boolean) setHypActiveSupressed: (boolean) aBoolean
{
   hypLastActiveSupressed = hypActiveSupressed;
   hypActiveSupressed = aBoolean;
   [proxyNode setHypActiveSupressed: aBoolean];
   return hypActiveSupressed;
}

-(boolean) getRealActive
{
   return realActive;
}


-(boolean) getLastRealActive
{
  // overridden in Nary nodes to use groups

   return lastRealActive;
}

-(boolean) getHypActive
{
   return hypActive;
}

-(boolean) setRealActive: (boolean) aBoolean
{
   realActive = aBoolean;
   [proxyNode setRealActive: aBoolean];

   return realActive;
}


-(boolean) setHypActive: (boolean) aBoolean
{
   hypActive = aBoolean;
   [proxyNode setHypActive: aBoolean];
   return hypActive;
}

-moveSuspendedOwner: (id) anOwner
{
// If the owner has not improved on this node's predictions, allow this
// node to participate in new connections.  Trick the node it predicts 
// (if detector) not to create a new predictive node, by making 
// suspended predictions

  [activeOwnerList addLast: anOwner];
  [suspendedOwnerList remove: anOwner];

  return self;
}

// Check this routine - I've no idea if it is right

-addOwnerShare: (double *) rewardPtr
{
   int count = [nodeList getCount];

   while (count > 0)  
   {
      count--;
      if ([[nodeList atOffset: count] getFired])
      {
          [[nodeList atOffset: count] addOwnerShare: rewardPtr];
          return self;
      }  
   }
   return self;
}

-getPredictorList
{
   return [proxyNode getPredictorList];
}

-getActivePredictorList
{
    return [proxyNode getActivePredictorList];
}

-getPreviousNodeList
{
    return previousNodeList;
}

-getHypActivePredictorList
{
    return [proxyNode getHypActivePredictorList];
}


-getSuspendedPredictorList
{
    return [proxyNode getSuspendedPredictorList];
}

-getHypSuspendedPredictorList
{
    return [proxyNode getHypSuspendedPredictorList];
}

-getPassivePredictorList
{
   return [proxyNode getPassivePredictorList];
}


-getHypPassivePredictorList
{
   return [proxyNode getHypPassivePredictorList];
}

-(boolean) getActivePredicted
{
   return activePredicted;
}

-(boolean) getHypActivePredicted
{
   return hypActivePredicted;
}

-(boolean) getPassivePredicted
{
   return passivePredicted;
}

-(boolean) getHypPassivePredicted
{
   return hypPassivePredicted;
}

-(boolean) getSuspendedPredicted
{
   return suspendedPredicted;
}


-(boolean) getHypSuspendedPredicted
{
   return hypSuspendedPredicted;
}

-setActivePredicted: (boolean) aBoolean
{

   activePredicted = aBoolean;

   return self;
}

-setHypActivePredicted: (boolean) aBoolean
{

   hypActivePredicted = aBoolean;

   return self;
}

// I think these following two methods are defunct (and wrong)

-getActiveOwnerList
{
  return [[self getFirstNode] getActiveOwnerList];
}

-getSuspendedOwnerList
{
  return [[self getFirstNode] getSuspendedOwnerList];
}

-setPassivePredicted: (boolean) aBoolean
{
   passivePredicted = aBoolean;

   return self;
}


-setHypPassivePredicted: (boolean) aBoolean
{
   hypPassivePredicted = aBoolean;

   return self;
}


-setSteadyState: (boolean) aBoolean
{
   int count;
   
   count = [nodeList getCount];
   [proxyNode setSteadyState: aBoolean];

   while (count > 0)
   {
       count--;
       if ([nodeList atOffset: count] != proxyNode)
          [[nodeList atOffset: count] setSteadyState: aBoolean];
   }

   return self;
}

-setSuspendedPredicted: (boolean) aBoolean
{
     suspendedPredicted = aBoolean;
     return self;
}


-setHypSuspendedPredicted: (boolean) aBoolean
{
     hypSuspendedPredicted = aBoolean;
     return self;
}

-getNodeList
{
    return [nodeList copy: [agentModel getZone]];
}


-temporalActivated
{
  return self;
}

// Feb 21 2001 - receiving this sets the primaryNode for a group and
// therefore its action. This method then forwards the message to
// prior groups.

-chainCorrect: (boolean) aBoolean 
{
  // This will select as a primary node, the best node in the group.
  // as nodes only update their values when the chain matches,
  // and makes a prediction each node should accurately represent its
  // approximate value.

  // Once you have completed your trials (note: some nodes may not
  // complete trials before they are extended, but will rather
  // complete them after they have been extended.
  // These nodes will have been extended based on passing the prediction
  // a number of times).  

  if (aBoolean) {
    [self correct];
  }
  else
    [self incorrect];

  if (!topGroup)
    [[self getPreviousNodeList] forEach: M(chainCorrect:) : (void *) aBoolean];

  return self;
}

// Nov 14 2000 - correct and incorrect for temporal nodes is significant
// now.

-correct
{ 

  int count = [nodeList getCount];

  // Nov 14 2000 - to only update when chain completes - uncomment 
  // following line
  //[firstNode sendPreviousCorrect: True];
  while (count > 0) {
    count--;
    [[nodeList atOffset: count] correct];
  } 
   return self;
}


-setCorrect: (boolean) aBoolean
{
  int count = [nodeList getCount];
  while (count > 0) {
    count--;
    [(PredictorNode *) [nodeList atOffset: count] setCorrect: aBoolean];
  } 
  return self;
} 

// Oct 16 2000 - The 1st group is sent incorrect by terminal node
// this group then sends to previous 
-incorrect
{
  int count = [nodeList getCount];

  // Nov 14 2000 - to only update when chain completes - uncomment 
  // following line

  //[firstNode sendPreviousCorrect: False];
  while (count > 0) {
    count--;
    [[nodeList atOffset: count] incorrect];
  } 
   return self;
}

-getProxyNode
{
    return proxyNode;
}

-setSuspended: (boolean) aBoolean
{
  int count = [nodeList getCount];
  
  if (suspended == aBoolean)
    return self;

  if ((([nodeList getCount] > 0) 	
	&& ![[nodeList getFirst] respondsTo: M(isUnary)])
    && (aBoolean == False))		
     [agentModel addActiveGroup];

  if ([firstNode respondsTo: M(isTemporal)] 
   || [firstNode respondsTo: M(isTerminal)])
    {
      if ([agentModel getDebug])
	printf("\n temporal group set suspended %ld: %d, count: %d", 
	       nodeNumber, aBoolean, count);
      
      // The terminal node of the temporal group should never
      // be added as active
      if ([firstNode respondsTo: M(isTemporal)] 
	  && terminalNode != nil)
	[agentModel removeActive: terminalNode];

      suspended = aBoolean;
      [(PredictorNode *) proxyNode setSuspended: aBoolean];
      while (count > 0)  
	{
	  count--;
	  [(PredictorNode *)[nodeList atOffset: count] setSuspended: aBoolean];
	}
    }
  else
    {
      [(PredictorNode *) proxyNode setSuspended: aBoolean];
      while (count > 0)  
	{
	  count--;
	  [(PredictorNode *)[nodeList atOffset: count] setSuspended: aBoolean];
	}
      
      suspended = aBoolean;
    }
  return self;
}

-(boolean) getSuspended
{
  return suspended;
}

// This is a version of setsuspended for non-temporal and terminal nodes
// to set all nodes to suspended. Used for temporallySuspended groups.

-setAllSuspended: (boolean) aBoolean
{
  int count = [nodeList getCount];
  
  suspended = aBoolean;
  [(PredictorNode *) proxyNode setSuspended: aBoolean];
  
  while (count > 0)  
    {
      count--;
      [(PredictorNode *)[nodeList atOffset: count] setSuspended: aBoolean];
    }
  return self;
}


-checkUpdateTemporalSupress
{

 // May 22 2001 - this prevents lower nodes from updating value estimates
  //  and counters - similar to activeSupression for NaryNodes.

  if (![proxyNode respondsTo: M(isTemporal)]
      || ![[self getTopGroup] getFinalGroup])
    return self;

  [proxyNode checkUpdateTemporalSupress];
  return self;

}

-isGroup
{
  return self;
}

-(void) die
{
  if (removed)
    {
      [nodeList drop];
      [rewardList drop];
    }
}

-getFirstNode
{

// If it is a detector group, the first node may not have been set
// yet, so return the proxy node, which then has a prediction set.

// have to copy first node otherwise we lose the owner's and don't get down
// wards messages.

  // NB: Overridden for TerminalGroups as firstnode in list is a dummy,
  // so the real first node is kept in a variable.

  if (firstNode == nil)
    return proxyNode;
  else
    return firstNode;
}


-findSimilarTerminalNode: (id) aNode
{

  // this will find a node with the same prediction and effector as
  // the parameter node. It is intended to be sent to group of a newly 
  // created terminal node's first input

  int count = [nodeList getCount];

  while (count > 0) {
    count --;
    if (([(PredictorNode *)[nodeList atOffset: count] getSupported] 
	 == [(PredictorNode *) aNode getSupported])
	// Sept 21 2000 - only return those nodes which
	// exceed activation count (primarily for terminal remove)
	&& [[nodeList atOffset: count] getActivated]
	// Sep 19 2001 - replaced following with above
	//	&& ([[nodeList atOffset: count] getActivationCount]
	//    > [agentModel getActivationThreshold])
	&& ![[nodeList atOffset: count] getTemporallySuspended]
     && ([[nodeList atOffset: count] getPrediction] == [aNode getPrediction]))
      return [nodeList atOffset: count];
  }
  return nil;
}

-findSimilarTemporalNode: (id) aNode 
{
  // this will find a node with the same effector as
  // the parameter node and effectively the same prediction, as temporal
  // nodes predict their next input, it will look for a node which
  // predicts the same group as the temporal node's next input. 
  // It is intended to be sent to the group of a temporal node's first input
  // for newly created temporal nodes.

  int count = [nodeList getCount];

  // There is a difference between temporal nodes at the start of a chain and
  // subsequent temporal nodes
  if ([[aNode getGroup] getTerminalNode] != nil) {
    while (count > 0) {
      count --;
      if (([(PredictorNode *) [nodeList atOffset: count] getSupported] 
	   == [(PredictorNode *) aNode getSupported])
	 && ![[nodeList atOffset: count] getTemporallySuspended]
	  && ([[nodeList atOffset: count] getPrediction]  
	      == [[[[[[aNode getGroup] getProxyNode] 
		    getInputList] getLast] getNode] getGroup]))
	return [nodeList atOffset: count];
    }

  }
  else {
    while (count > 0) {
      count --;
      if (([(PredictorNode *) [nodeList atOffset: count] getSupported] 
	   == [(PredictorNode *) aNode getSupported])
	  && ![[nodeList atOffset: count] getTemporallySuspended]
	  && ([[nodeList atOffset: count] getPrediction]  
	      == [[[[[[[[[[[aNode getGroup] getProxyNode] 
		    getInputList] getLast] getNode] getGroup] getProxyNode]
		      getInputList] getFirst] getNode] getGroup]))
	return [nodeList atOffset: count];
    }
  }
  return nil;
}

-setHypStrength: (float *) aStrength
{
   if ([agentModel getDebug])
       printf("\n node group: %ld, hyp strength recieved: %f", 
         nodeNumber,*aStrength);

    hypStrength = *aStrength;
    return self;
} 

-setReward
{
  // Changed all this - now just updates average which is used
  // for discounted terminal values.

  // July 2 2002 - changed following:

  if (([proxyNode respondsTo: M(isTemporal)] 
       && [proxyNode getFirstInputMatchedNow]
       && finalGroup)
      || (![proxyNode respondsTo: M(isTemporal)] &&
	  matched)) {
    strength = [(AgentModelSwarm *) agentModel getReward];
    averageReward = averageReward + [agentModel getLearningRate] *
      ([agentModel getReward] - averageReward);
  } else
    strength = 0;

  if ([agentModel getDebug])
    fprintf(stdout,"\n NodeGroup: %ld getting reward matched: %d, \n activeSupressed: %d, strength %f ", 
	    nodeNumber, matched, activeSupressed, strength);
  
  return self;
}
    

-drawSelfOn: (Raster *) aRaster
{
   [nodeList forEach: M(drawSelfOn:) :(id) aRaster];
   return self;
}


-(boolean) getActiveSuppressedAtStart
{
    return activeSuppressedAtStart;
}


-setActiveSuppressedAtStart: (boolean) aBool
{
  activeSuppressedAtStart = aBool;
  return self;
}




-(boolean) getActiveSupressed
{
    return activeSupressed;
}


-(boolean) getActiveTemporallySupressed
{
    return activeTemporallySupressed;
}


-(boolean) getHypActiveSupressed
{
    return hypActiveSupressed;
}

-getTerminalNode
{
   return terminalNode;
}

-setTerminalNode: (id) aNode
{
    terminalNode = aNode;
    return self;
}

-setTopGroup: (boolean) aBoolean
{
  // reset temporalactivation count, or if our extension was removed
  // the entire chain may be removed Oct 16 2000
  if (aBoolean == True) { 
    if (temporalActivationCount >
	[agentModel getTemporalActivationThreshold])
      temporalActivationCount = [agentModel getTemporalActivationThreshold];
  }
  topGroup = aBoolean;
  return self;
}

// This is for node higher in the chain. As they are created they 
// are passed the chains terminal group (other than the first temporal
// group as it has access through the terminalNode).  This group can then be
// queried as to whether it is final or not.  As new nodes are added they
// set themselves as topGroup in the terminalGroup 

-setTerminalGroup: (id) aGroup
{
  terminalGroup = aGroup;
  return self;
}

-getTerminalGroup
{
  return terminalGroup;
}

-getTopGroup
{
    return [terminalGroup getTopGroup];
}

-(boolean) isTopGroup
{
   return topGroup;
}

-setFinalGroup: (boolean) aBoolean
{
  if ([agentModel getDebug])
    fprintf(stdout, "\n nodeGroup %ld setting final group to: %d",
	nodeNumber, aBoolean);

// Nov 23: This tells the terminal group that the chain is established,
// passes the prediction so that it can remove from its input node any
// nodes which make this prediction, as these nodes are now replaced by the
// chain nodes. -- Called now by TerminalNode when setting finalgroup.
//   [terminalGroup setFinalPrediction: [firstNode getPrediction]]; 

  finalGroup = aBoolean;
  return self;
}


// returns the max average return received by this group

-(double) getAverageReturn 
{
    return averageReturn;
}


// returns the max average reward received by this group

-(double) getAverageReward 
{
     return averageReward;
}

-(double) getAbsAverageReturn 
{
  if (averageReturn > 0)
     return averageReturn;
  else 
    return (averageReturn * -1);
}


// use this when comparing to lower nodes
// as it allows for negative rewards 

// Note: this value will always be a little off from the highest independent
// value of the group, because this is updated prior to the next return
// being received (it is one step behind). 
// Also as the return is discounted in the receiver, we need to discount
// it here, or comparisons will overrate the averageReinforcement in comparison
// to the independent and dependent returns it is compared to.

-(double) getAverageReinforcement
{
  double calc = 0;

  calc = (averageReturn * [agentModel getDiscountRate]) + averageReward;

  return calc;
}

-(double) getAbsAverageReinforcement
{
  double calc = 0;

  calc = (averageReturn * [agentModel getDiscountRate]) + averageReward;

  if (calc > 0)
    return calc;
  else
    return (calc * -1.0);
}


- (boolean) getFinalGroup
{
   return finalGroup;
}


-checkCreateTemporalOk 
{
 // Nov 23 2000 - because for unfinished
  // chains new links can be added and removed from the ends, to prevent
  // duplicates, if you are the first group in a chain, and
  // you are unfinalised, you must prevent other chains from being
  // created if both your inputs are matched.

  // Note that createTemporalOk is also set in match below
  // for finalised chains

  //if ((terminalNode != nil))
    // Dec 7 2000 - removed following
      //      && ![[self getTopGroup] getFinalGroup])
  if ([proxyNode respondsTo: M(isTemporal)])
    [(TemporalNode *) proxyNode checkCreateTemporalOk];

  return self;
}


// removes the top group for a chain if it doesn't lead to either
// the prediction being correctly predicted or the chain being
// correctly predicted (a cycle).

// Only check this once the chain has made a prediction. 
// If firstinputmatchednow, a cycle has occured, this is ok,
// skip check.

-checkTemporalRemove
{

  id inputProxy = nil;
  id inputNode = nil;
  boolean removeExtension = False;
  id prediction;

  if (removed)
    return self;

 // April 22 2002 - if reset and extended this temporal cycle,
  // remove most recent extension.

  if ([agentModel getDebug])
    if (firstNode != nil && topGroup)
      printf("\n group: %ld, topGRoup: %d, final: %d reset: %d rActive: %d", 
	     nodeNumber, topGroup, finalGroup, [proxyNode getResetChain],
	     realActive);

  if (topGroup 
      && [proxyNode respondsTo: M(isTemporal)] 
      && ![self getFinalGroup]
      && ([proxyNode getRealActive]
	  // July 2 2002 - added following:
	  || [proxyNode getResetChain])
 // this is called after realActive
                         // it is set for timestep in which it is matched
      // if correct once in past, the above should not matter,
      // it only applies when the chain does not predict
      // the prediction but a cycle exists.
      //  cannot use if firstInputMatched, as the presence of a top group
      // would have prevented this flag being set, we must explicity 
      // check this now.
      // Mar 2 2001 - allow a number of trials before removing most recent
      // extension, this takes longer, but otherwise the extensions never
      // extend to the start nodes, as the chain is rarely followed and these
      // are removed.
      // - no its too complex and doesn't work, insist that a teacher
      // always takes shortest path otherwise may as well represent every
      // possible path. 
      //      && (temporalActivationCount 
      //  > [agentModel getTemporalActivationThreshold])
      && ([(TerminalGroup *) [self getTerminalGroup] 
			     getChainCorrectCount] == 0))
    {

      // If you are the first node, don't do this test, as
      // the prediction must have been matched when you were
      // created (however, may not match your best action when selected?)
      
      if (![[[[firstNode getInputList] 
	       getLast] getNode] respondsTo: M(isTemporal)])
	return self;

      //Nov 28 2000 - used to just check if fim, but now 
      // actually set the chainCorrectCount to indicate a cycle
      // probably should use a separate counter, but this will do.
 
      prediction = [[[self getTerminalGroup] getFirstNode] 
		     getPrediction];
      if ([agentModel getDebug])
	printf("\n Node Group: %ld, checkTemporalRemove, \n prediction matched: %d", nodeNumber,  [prediction getMatched]);

      if (([prediction respondsTo: M(isTemporal)]
	   // Don't rely on FIMN 
	   && [[[[prediction getInputList] getFirst] getNode] getMatched])
	  || (![prediction respondsTo: M(isTemporal)]
	      && [prediction getMatched]))
	// Ok - don't remove recent extension
	[(TerminalGroup *) [self getTerminalGroup] 
			   incrementChainCorrectCount];
      else {
	inputNode = [[[proxyNode getInputList] getFirst] getNode];
	
	if ([inputNode getMatched]) {
	  // 30 Jan 2001 - new condition for cycles - to ensure latest
	  // extension is on the path for this chain's prediction,
	  // the chain must have been reset by the prediction 
	  // when the latest extension was added (if prediction is !matched).
	  // this does not ensure a chain will represent the
	  // shortest path unless the shortest path is always followed.
	  // It does prevent the chain being extended on paths to other 
	  // endpoints which may be longer.
	  
	  if ([[self getTerminalGroup] getPredictionPassedFlag]) {
	    [(TerminalGroup *) [self getTerminalGroup] 
			       incrementChainCorrectCount];
	    if ([agentModel getDebug])
	      printf("\n setting prediction passed to False for node: %ld",
		     nodeNumber);
	    [[self getTerminalGroup] setPredictionPassedFlag: False];
	  }
	  else {
	    if ([agentModel getDebug])
	      printf("\n prediction not passed");
	    removeExtension = True;
	  }
	}
	else {
	  if ([agentModel getDebug])
	    printf("\n no cycle exists and prediction not matched");
	  removeExtension = True;
	}
      }

      if (removeExtension){
	inputProxy = [[[[proxyNode getInputList] getLast] getNode] getGroup];
	
	if ([agentModel getDebug])
	  printf("\n node group %ld, removing topgroup in check temporal remove\nrealActive: %d, fimn: %d",
		 nodeNumber, realActive, [proxyNode getFirstInputMatchedNow]);
	[[self getTerminalGroup] removeTopGroup];

	if (removed) { // if first link in chain, it will not be removed
	  // Need to set second input matched now and waitingOnSecond
	  // Nov 20 2000
	  if ([[inputProxy getProxyNode] respondsTo: M(isTemporal)])
	    [inputProxy ownerRemoved];
	}

	[[self getTerminalGroup] setPredictionPassedFlag: False];

	// April 4 - ok just go straight to next extension
	// as there is no point collecting stats on something that is
	// never going to be correct

	// July 12 2002 - reset for all nodes in group:

	[(TerminalGroup *) [self getTerminalGroup] resetTemporallyActivated];
	
	// Feb 1 2001 - set new top group to be first input matched if
	// its input is currently matched, otherwise set it to
	// waitingOnFirstInput.
	if ([[[[[[self getTopGroup] getProxyNode] 
		 getInputList] getFirst] getNode] getMatched]) {
	  [[[self getTopGroup] getProxyNode] setFirstInputMatchedNow: True];
	  [[[self getTopGroup] getProxyNode] setSecondInputMatchedNow: False];
	  [[[self getTopGroup] getProxyNode] setWaitingOnFirstInput: False];
	  [[[self getTopGroup] getProxyNode] setWaitingOnSecondInput: True];
	}
	else {
	  [[[self getTopGroup] getProxyNode] setFirstInputMatchedNow: False];
	  [[[self getTopGroup] getProxyNode] setSecondInputMatchedNow: False];
	  [[[self getTopGroup] getProxyNode] setWaitingOnFirstInput: True];
	  [[[self getTopGroup] getProxyNode] setWaitingOnSecondInput: False];
	}
      }
    }

  return self;
}


// Nov 20 2000 - added the following to check if first input matched
// once owner removed so we can extendTemporal the same timestep.

-ownerRemoved
{
  if ([[[[proxyNode getInputList] getFirst] getNode] getMatched]) {
    [proxyNode setFirstInputMatchedNow: True];
    [proxyNode setWaitingOnSecondInput: True];
    // Nov 20 2000 - deterministic select was too strong
    // probabilistic select should ensure that
    // randomness is reduced in clear cases.
    //    [agentModel setDeterministicSelect: True]; 
    // Nov 16 2000 - added following line (and storedRate in AgentMS).
    //  Jan 31 2001 - remvoed following
    //    [agentModel setRandomEffectorRate: 0];
    // Need to do this as setTopGroup sets it too one less than
    // agentModelActivationCount.
     temporalActivationCount++; 
  }
  return self;
}

-incrementLifetimeCount
{

    [nodeList forEach: M(incrementLifetimeCount)];
  
   return self; 
} 

// July 12 2002 - reset for all nodes:

-resetTemporallyActivated {
  [nodeList forEach: M(resetTemporallyActivated)];
  return self;
}

-(boolean) reset
{
  //   lastActiveTemporallySupressed=False;
  //activeTemporallySupressed = False;
  // activeSupressed = False;
   //  lastActiveSupressed = False;

   [self resetMatched: False];
   realActive = False;
   lastRealActive = False;
   previousRealActive = False;
   return True;
}

-setAcceptingMessages: (boolean) aBoolean
{
   int count;
   
   count = [nodeList getCount];

   while (count > 0)
   {
       count--;
       if (((long)[nodeList atOffset: count]) != ((long) proxyNode)) {
         if ([agentModel getDebug])
        	 fprintf(stdout, "\n Temporal node: %ld received setAcceptingMessages: %d", [[nodeList atOffset: count] getNodeNumber], aBoolean);
          [[nodeList atOffset: count] setAcceptingMessages: aBoolean];
       }
   }

   return self;
}

-setWaitingOnSecondInput: (boolean) aBoolean
{
   int count;
   
   count = [nodeList getCount];

   while (count > 0)
   {
       count--;
       if (((long)[nodeList atOffset: count]) != ((long) proxyNode)) {
         if ([agentModel getDebug])
        	 fprintf(stdout, "\n Temporal node: %ld received setWaitingOnsecondInput: %d", [[nodeList atOffset: count] getNodeNumber], aBoolean);
          [[nodeList atOffset: count] setWaitingOnSecondInput: aBoolean];
       }
   }

   return self;
}

-setWaitingOnFirstInput: (boolean) aBoolean
{
   int count;
   
   count = [nodeList getCount];

   while (count > 0)
   {
       count--;
       if ([nodeList atOffset: count] != proxyNode)
          [[nodeList atOffset: count] setWaitingOnFirstInput: aBoolean];
   }

   return self;
}


-setSecondInputMatchedNow: (boolean) aBoolean
{
   int count;

   count = [nodeList getCount];

   while (count > 0)
   {
       count--;
       if ([nodeList atOffset: count] != proxyNode) {
          [[nodeList atOffset: count] setSecondInputMatchedNow: aBoolean];
       }
   }

   return self;
}

-(boolean) getMatchedNow
{
  if ([agentModel getDebug])
    printf("\n getMatchedNow for group: %ld, realActive: %d matched: %d",
	   nodeNumber, realActive, matched);

  if ([proxyNode respondsTo: M(isTemporal)])
      return [(TemporalNode *) proxyNode getFirstInputMatchedNow];
  else
    return realActive;
}

-setFirstInputMatchedNow: (boolean) aBoolean
{
   int count;

   count = [nodeList getCount];

   while (count > 0)
   {
       count--;
       if ([nodeList atOffset: count] != proxyNode)
          [[nodeList atOffset: count] setFirstInputMatchedNow: aBoolean];
   }

   return self;
}

-(int) getImprovedNodeCount{
  return improvedNodeCount;
}

-incrementImprovedNodeCount
{
  improvedNodeCount++;
  return self;
}
  
-decrementImprovedNodeCount
{
  improvedNodeCount--;
  return self;
}

-(int) getResetCount
{
  return resetCount;
}

-incrementResetCount
{
  resetCount++;
  return self;
}

-inhibitNodes: (boolean) aBoolean
{

  // Nodes are inhibited when they are part of a chain which has not 
  // established a finalGroup, after that they are temporallySuspended
  // In fact, it is probably sufficient just to store this variable
  // in the group.

   int count;

   count = [nodeList getCount];
   inhibited = aBoolean;
  
   while (count > 0)
   {
       count--;
       [[nodeList atOffset: count] setInhibited: aBoolean];
   }

   return self;
}

-setNodesSuspended 
{

  // nodes are set to temporallySuspended when the final group is established
  // These nodes can never be used again. New nodes are copied to replace them
  // where required.

   int count;

   count = [nodeList getCount];


   // The getSuspendLastCorrect will determine whether all nodes in the 
   // lower group are set to temporallySuspended or only those whose 
   // prediction was matched at the same time as the terminal node's. As
   // this is only called when the terminal node was correct and the final
   // group has been determined, only nodes belonging to this chain
   // will be set to temporallySuspended. The alternative sets all nodes
   // to temporally suspended. You might want to do this if you are concerned
   // about having the predictive accuracy and strength reflect the experience
   // after the chain was completed. This would only really matter if averages
   // were being used to calculate these values. This alternative loses all
   // information on the alternate path and starts from scratch.

   while (count > 0)
   {
       count--;
       if ([agentModel getSuspendLastCorrect]) {
	 // getMatchedNow takes into account temporal predictions
	 // this option should be avoided, as it does not
	 // work in some situations June 19 2000
	 if ([[[nodeList atOffset: count] getPrediction] getMatchedNow])
	   [[nodeList atOffset: count] setTemporallySuspended: True];
       }
       else
	 [[nodeList atOffset: count] setTemporallySuspended: True];
   }

   return self;
}

-setFired: (boolean) aBoolean
{
    fired = aBoolean;
    return self;
}

-setHigherValue: (boolean) aBoolean
{
  higherValue = aBoolean;
  return self;
}

-(boolean) getHigherValue
{
  return higherValue;
}

-(boolean) getRemoved {
  return removed;
}

-setPrimaryNode: (id) aNode
{
  primaryNode = aNode;
  return self;
}

-getPrimaryNode {
  return primaryNode;
}

-(boolean) getTemporallySuspended
{
   if (terminalNode == nil)
       return False;
   return [[terminalNode getGroup] getTemporallySuspended];
}

-terminalNodeMatch: (boolean) aBoolean
{
   if (terminalNode != nil)
      [terminalNode match: aBoolean];
   return self;
}

-(int) getNodeCount {
  return [nodeList getCount];
}

-terminalNodeSetMatched: (boolean) aBoolean
{
   if (terminalNode != nil)
      [[[terminalNode getGroup] getProxyNode] setMatched: aBoolean by: nil];
   return self;
}

-printOn
{

  // Unary groups may not have a first node.


  if (firstNode != nil)
    printf("\n ----------- Node Group %ld contains %d Nodes -----firstNode: %ld",
            nodeNumber, [nodeList getCount], [firstNode getNodeNumber]);
  else
    printf("\n ----------- Node Group %ld contains %d Nodes -----firstNode: %d",
            nodeNumber, [nodeList getCount], 0);

  if ([proxyNode respondsTo: M(isTemporal)]) {
    if (primaryNode != nil)
      printf("\n ----------- Primary Node: %ld effector: %d",
	     [primaryNode getNodeNumber], 
	     [(Effector *) [(NaryNode *) primaryNode getSupported] 
			   getPosition]);
    else
      printf("\n ----------- Primary Node not determined");
  }
  printf("\nRemoved: %d Average return: %f, averageReward: %f", removed, averageReturn, averageReward);
  printf("\n temporalActivationCount: %d improvedCount: %d", temporalActivationCount, [self getImprovedNodeCount]);
  
  if ([proxyNode respondsTo: M(isTerminal)])
    printf("\n chainCorrectCount: %d",
	   [(TerminalGroup *) self getChainCorrectCount]);
  
  fflush(stdout);    
  
  [nodeList forEach: M(printOn)];
  [proxyNode printOn]; 
  
  printf("\n proxy node predictors ******************");
  fflush(stdout);    
  
  [[proxyNode getPredictorList] forEach: M(printOn)];

  if ([[self getPreviousNodeList] getCount] > 0) {
    printf("\n previous node list ******************");
    [[self getPreviousNodeList] forEach: M(summaryOn)]; 
  }
  printf("\n ------------------------------------------------------------");
  return self; 
}

-(int) getHighestAction {
  return highestAction;
}

-getHighestActionNode {
  return highestActionNode;
}

-setHighestAction: (int) anInt node: aNode {
  highestAction = anInt;
  highestActionNode = aNode;
  return self;
}

-summaryOn {

  id node;

  if ([nodeList getCount] == 0) {
       return self;
  }

  node = [nodeList getFirst];

  if (![node respondsTo: M(isUnary)]
     && ![node respondsTo: M(isTemporal)]
     && ![node respondsTo: M(isTerminal)])       	
     printf("\n Node Group: %ld, firstInput: %ld, secondInput: %ld suspended: %d",
       nodeNumber,[[[[[node getInputList] getFirst] getNode] getGroup] 
	getNodeNumber],
	[[[[[node getInputList] getLast] getNode] getGroup] 
		getNodeNumber], suspended);

  return self;
}


// April 11 2002 - added following methods:

-setFrequencyFrom: (PredictorNode *) aNode {
  int position = 0;

  position = [(Effector *) [(PredictorNode *) aNode getSupported] getPosition];
  
  if ([aNode getDependentValue] > 0) {
    if (mostFrequentPositive[position] != nil) {

      if ([aNode getDependentValue] > 
	  [mostFrequentPositive[position] getDependentValue]) {
	mostFrequentPositive[position] = aNode;
      }
    } else {
      mostFrequentPositive[position] = aNode;
    }
  } else
    if ([aNode getDependentValue] < 0) {
      if (mostFrequentNegative[position] != nil) {

	if ([aNode getDependentValue] < 
	    [mostFrequentNegative[position] getDependentValue]) {
	  mostFrequentNegative[position] = aNode;
	}
      } else {
	mostFrequentNegative[position] = aNode;
      }
    }

  return self;
}

-getMostFrequentPositive: (id) aNode {
  int position = 0;

  position = [(Effector *) [(PredictorNode *) aNode getSupported] getPosition];
  return mostFrequentPositive[position];
}

-setMostFrequentPositive: (id) aNode to: (id) node {
  int position = 0;

  position = [(Effector *) [(PredictorNode *) aNode getSupported] getPosition];
  mostFrequentPositive[position] = node;
  return self;
}

-getMostFrequentNegative: (id) aNode {
  int position = 0;

  position = [(Effector *) [(PredictorNode *) aNode getSupported] getPosition];
  return mostFrequentNegative[position];
}

-setMostFrequentNegative: (id) aNode to: (id) node {
  int position = 0;

  position = [(Effector *) [(PredictorNode *) aNode getSupported] getPosition];
  mostFrequentNegative[position] = node;
  return self;
}

-(float) getInterest {
  return interest;
}

-setAccuratelyPredictedOk: (boolean) aBool {
  accuratelyPredictedOk = aBool;
  return self;
}

-(boolean) getAccuratelyPredictedOk {
  return accuratelyPredictedOk;
}

-setAccuratelyTemporallyPredictedOk: (boolean) aBool {
  accuratelyTemporallyPredictedOk = aBool;
  return self;
}

-(boolean) getAccuratelyTemporallyPredictedOk {
  return accuratelyTemporallyPredictedOk;
}

-printAsRule {

  id firstInputTxt = nil;
  id firstInput = nil;
  id secondInputTxt = nil;
  id secondInput = nil;
  float max = 0;

  if (!removed && (!suspended || [agentModel getTrackRules]) 
      && ![proxyNode respondsTo: M(isUnary)]) {
    if (![proxyNode respondsTo: M(isTemporal)]
	&& ![proxyNode respondsTo: M(isTerminal)]) {
      printf("\nRule group number: %ld", nodeNumber);
      printf("\n\t Average reward: %f, averageReturn: %f", averageReward,
	     averageReturn);

      firstInput = [[[proxyNode getInputList] getFirst] getNode];
      if ([firstInput respondsTo: M(isUnary)]) {
	firstInputTxt = [agentModel lookUpInputName: 
				      [firstInput getNodeNumber]];
	printf("\n\t%s", [firstInputTxt getC]);	
      } else {
	printf("\n\tAND (first input for %ld not unary):", nodeNumber);
	[[firstInput getGroup] printAsRule];
	printf("\n\tfinished first input for %ld", nodeNumber);
      }
      secondInput = [[[proxyNode getInputList] getLast] getNode];
      if ([secondInput respondsTo: M(isUnary)]) {
	secondInputTxt = [agentModel lookUpInputName: 
				      [secondInput getNodeNumber]];
	printf("\n\tAND %s", [secondInputTxt getC]);
      } else {
	printf("\n\tAND (second input for %ld not unary):", nodeNumber);
	[[secondInput getGroup] printAsRule];
	printf("\n\tfinished second input for %ld", nodeNumber);
      }
      if ([agentModel getSelectBest]) {
	highestAction = [(Effector *) [(PredictorNode *) [nodeList getFirst] 
					    getSupported] getPosition];
	highestActionNode = [nodeList getFirst];
	max = [[nodeList getFirst] getDependentValue];
	printf("\n First node: %ld, value: %f", 
	       [[nodeList getFirst] getNodeNumber], 
	       [[nodeList getFirst] getDependentValue]);

	[nodeList forEach: M(getHighestAction:) : (void *) &max];
	printf("\n\tHighest Supported Effector: %s", 
	       [[agentModel lookUpEffectorName: highestAction] getC]);
	printf("\n\tSupporting node is improved: %d", 
		 [highestActionNode getImproved]);
      } else
	[self printEffectorTotals];
      if ([agentModel getDebug]) {
	printf("\n");
	[nodeList forEach: M(printAsRule)];
	printf("\n\n");
      }
    } else {
      if ([proxyNode respondsTo: M(isTemporal)]) {
	printf("\nRule temporal group number: %ld", nodeNumber);
	printf("\n\t Average reward: %f, averageReturn: %f", averageReward,
	       averageReturn);
	firstInput = [[[proxyNode getInputList] getFirst] getNode];
	if ([firstInput respondsTo: M(isUnary)]) {
	  firstInputTxt = [agentModel lookUpInputName: 
					[firstInput getNodeNumber]];
	  printf("\n\t AT T0: %s", [firstInputTxt getC]);
	  printf("\n\t\t T0 Effector: %s", 
		 [[agentModel lookUpEffectorName: 
		   [(Effector *) [(PredictorNode *) firstNode getSupported] 
				 getPosition]] getC]);
	} else {
	  printf("\n\t AT T0 (first input for %ld not unary):", nodeNumber);
	  [[firstInput getGroup] printAsRule];
	  printf("\n\tfinished first input for %ld", nodeNumber);
	  printf("\n\t\t T0 Effector: %s", 
		 [[agentModel lookUpEffectorName: 
	             [(Effector *)
		     [(PredictorNode *) firstNode getSupported]
		       getPosition]] getC]);
	}
	secondInput = [[[proxyNode getInputList] getLast] getNode];
	if ([secondInput respondsTo: M(isUnary)]) {
	  secondInputTxt = [agentModel lookUpInputName: 
					 [secondInput getNodeNumber]];
	  printf("\n\tAND AT T1: %s", [secondInputTxt getC]);
	} else {
	  printf("\n\tAND AT T1 (second input for %ld not unary):",nodeNumber);
	  [[secondInput getGroup] printAsRule];
	  printf("\n\tfinished second input for %ld", nodeNumber);
	}
	if ([agentModel getSelectBest]) {
	  highestAction = [(Effector *) [(PredictorNode *) [nodeList getFirst] 
					      getSupported] getPosition];
	  highestActionNode = [nodeList getFirst];
	  max = [[nodeList getFirst] getDependentValue];
	  [nodeList forEach: M(getHighestAction:) : (void *) &max];
	  printf("\n\tHighest Supported Effector: %s", 
		 [[agentModel lookUpEffectorName: highestAction] getC]);
	  printf("\n\tSupporting node is improved: %d", 
		 [highestActionNode getImproved]);
	} else
	  [[self getTerminalGroup] printEffectorTotals];
	if ([agentModel getDebug]) {
	  printf("\n");
	  [nodeList forEach: M(printAsRule)];
	  printf("\n\n");
	}
      }
    }
    printf("\n");
    fflush(stdout);
  }

  return self;
}

-probeNode: (int) number {
   [nodeList forEach: M(probeSelf:) : (void *) number];
   return self;
}


-probeSelf: (int) number {
  if (nodeNumber == number) {
    [self printOn];
  }
  return self;
}



// used to sum support for each effector for all nodes in group
// then divide by supporter count.

// allows us to determine which effector a group really encourages.

-printEffectorTotals {

  int effectorCount = 0;
  int x = 0;
  int position = 0;
  float support = 0;

  // NOTE IF WE HAVE MORE THAN 50 EFFECTORS THIS WILL CRASH!
  float effectorPositiveSums[50];
  int effectorPositiveSupporters[50];
  float effectorNegativeSums[50];
  int effectorNegativeSupporters[50];

  float effectorTotal[50];

  effectorCount = [agentModel getEffectorCount];

  for (x = 0; x < 50; x++) {
    effectorNegativeSums[x] = 0;
    effectorPositiveSums[x] = 0;
    effectorNegativeSupporters[x] = 0;
    effectorPositiveSupporters[x] = 0;
    effectorTotal[x] = 0;
  }

  for (x = 0; x < [nodeList getCount]; x++) {
    if ([(PredictorNode *) [nodeList atOffset: x] getSupported] != nil) {
      position = [(Effector *) [(PredictorNode *) 
		   [nodeList atOffset: x] getSupported] getPosition];
      support =  [[nodeList atOffset: x] getDependentValue];
      if (support > 0) {
	if (effectorPositiveSums[position] < support) 
	  effectorPositiveSums[position] = support;
	effectorPositiveSupporters[position]++;
      } else {
	if (support < 0) {
	  if (effectorNegativeSums[position] > support)  
	    effectorNegativeSums[position] = support;
	  effectorNegativeSupporters[position]++;
	}
      }
    }
  }

  for (x=0; x < effectorCount; x++) {

    /*
    if (effectorPositiveSupporters[x] > 0 && 
	effectorNegativeSupporters[x] > 0) { 
      support = (effectorPositiveSums[x] 
		 / (float) effectorPositiveSupporters[x]) +
	(effectorNegativeSums[x] 
	 / (float) effectorNegativeSupporters[x]);
    } else {
      if (effectorPositiveSupporters[x] > 0) 
	support = (effectorPositiveSums[x] 
		   / (float) effectorPositiveSupporters[x]);
      else
	if (effectorNegativeSupporters[x] > 0)
	  support = (effectorNegativeSums[x] 
		     / effectorNegativeSupporters[x]);
    }
    */
    if (effectorPositiveSupporters[x] > 0) 
      printf("\n\t Max Positive Support %f for effector %d, %s", 
	     effectorPositiveSums[x], x, 
	     [[agentModel lookUpEffectorName: x] getC]);
     if (effectorNegativeSupporters[x] > 0) 
      printf("\n\t Max Negative Support %f for effector %d, %s", 
	     effectorNegativeSums[x], x, 
	     [[agentModel lookUpEffectorName: x] getC]);

  }

  return self;
}

-hypDeactivate
{
     hypActivePredicted = False;
     hypPassivePredicted = False;     
     hypSuspendedPredicted = False;

     [proxyNode clearHypPredictors];

     [proxyNode setHypSupressed: False];  
     if (hypActive == False)
        [self setHypActive: [self getHypMatched]];

     [self setHypMatched: False];
     [proxyNode setHypMatched: False]; 
       
     return self;
}

-hypReset
{
     hypStrength = 0;
     hypActivePredicted = False;
     hypPassivePredicted = False;     
     hypSuspendedPredicted = False;

     [proxyNode clearHypPredictors];

     [proxyNode setHypSupressed: False];  
     [self setHypActive: False];
     hypActiveSupressed = False;
     hypLastActiveSupressed = False;
 
     [self setHypMatched: False];
     [proxyNode setHypMatched: False]; 
     return self;
}


@end









