/* bfs_1root.cpp
   search the graph from a single root node;
   if some nodes cannot be arrived, then set the 
   detection and finish time of these node as infinity (i.e. -1)

   ver: 0.2

   by PHC, July, 2002

  */

#include "graph.h"

#include "graphsupport.h"

//========================

//global variables

const int ColorWhite = 0;
const int ColorGrey = 1;
const int ColorBlack = 2;
const int ColorRed = 3;

class BFSClass //BreadthFirstSearchClass
{
public:
  long nnode;

  UBYTE * adjMatrix1d,  ** adjMatrix2d;

  BYTE * nodeColor; //decide if a node has been visited or not
  long * nodeLabel; //this will decide in which subgraph a node is in
  long * nodeParent; //for the DFS tree
  long * nodeDetectTime;
  long * nodeFinishTime;

  void dosearch();
  int allocatememory(long nodenum);
  void delocatememory();

  long rootnode;
  long setrootnode(long i) {
    rootnode=(i<0)?0:i; 
    rootnode=(rootnode>=nnode)?nnode:rootnode;
    return rootnode;
  }

  int b_disp;

  BFSClass() {
    nnode = 0;
    adjMatrix1d = 0;
    adjMatrix2d = 0;
    nodeColor = 0;
    nodeLabel = 0;
    nodeParent = 0;
    nodeDetectTime = 0;
    nodeFinishTime = 0;
    b_disp = 0;
    rootnode = 0;
  }
  ~BFSClass() {
    delocatememory();
    nnode = 0;
    rootnode = 0;
  }
};

void BFSClass::dosearch()
{
  if (nnode<=0 || !adjMatrix1d || !adjMatrix2d) {
    printf("The input data has not been set yet!\n");
    return;
  }
  
  long i,j,iu,iv;
  long * localQueue_node = 0;
  long queueHead = 0;
  long queueTail = 0;
  const long queueProtectLen = 128;
  long time;
  long curDCGLabel = 1;

  localQueue_node = new long [nnode+2*queueProtectLen];
  if (!localQueue_node) {
    printf("Fail to do: long * localQueue_node = new long [nnode];\n");
    goto Label_FreeMemory_Return;
  }

  // initialization

  for (i=0;i<nnode;i++) {
    nodeColor[i] = ColorWhite;
    nodeLabel[i] = -1;
    nodeParent[i] = -1;
    nodeDetectTime[i] = -1;
    nodeFinishTime[i] = -1;
  }
  time = 0;
  
  // begin BFS loop

  curDCGLabel = 1; //if the input graph is a symmetric undirected graph
                   //then this will return how many DCG in G
  for (i=rootnode;i<=rootnode;i++) {
    
    if (nodeColor[i]==ColorWhite) {

      queueHead = queueProtectLen; //protect both head and tail of queue
      queueTail = queueHead-1;

      nodeColor[i] = ColorGrey;
      nodeLabel[i] = curDCGLabel;
      nodeParent[i] = -1;
      nodeDetectTime[i] = ++time;

      //Enqueue
      queueTail++;
      localQueue_node[queueTail] = i; 
      if (queueTail>=nnode+queueProtectLen) {
	printf("The local queue is overflow!!!\n");
	goto Label_FreeMemory_Return;
      }
      if (b_disp) {
	printf("push %i\t queueHead = %i \tqueueTail = %i ===\n",i, queueHead, queueTail);
      }

      while (queueHead<=queueTail) {
	
	iu = localQueue_node[queueHead];

	for (j=0;j<nnode;j++) {

	  if (nodeColor[j]==ColorWhite && adjMatrix2d[j][iu]!=0) {
	    nodeColor[j] = ColorGrey;
	    nodeLabel[j] = curDCGLabel;
	    nodeParent[j] = iu+1; //the Matlab convention
	    nodeDetectTime[j] = nodeDetectTime[iu]+1;

	    //enqueue
	    queueTail++;
	    localQueue_node[queueTail] = j; 

	    if (queueTail>=nnode+queueProtectLen) {
	      printf("The local queue is overflow!!!\n");
	      goto Label_FreeMemory_Return;
	    }
	    if (b_disp) {
	      printf("push %i\t queueHead = %i \tqueueTail = %i\n",j,queueHead, queueTail);
	    }
	  }
	}

	queueHead++; //dequeue
	if (b_disp) {
	  printf("pop %i\t queueHead = %i \tqueueTail = %i\n",i, queueHead, queueTail);
	}
      
	nodeColor[iu] = ColorBlack;
	nodeFinishTime[iu] = ++time;
      }
      curDCGLabel++;
    }
  }

 Label_FreeMemory_Return:
  
  if (localQueue_node) delete []localQueue_node;

  return;
}//%================ end of DFS_dosearch()=================

int BFSClass::allocatememory(long nodenum) 
{
  if (nodenum>0) {
    nnode = nodenum;
  }

  int b_memory = 1;
  if (nnode>0) {
    delocatememory();
    b_memory = b_memory && (new1dArrayMatlabProtocal(nodeColor,nnode));
    b_memory = b_memory && (new1dArrayMatlabProtocal(nodeDetectTime,nnode));
    b_memory = b_memory && (new1dArrayMatlabProtocal(nodeFinishTime,nnode));
    b_memory = b_memory && (new1dArrayMatlabProtocal(nodeLabel,nnode));
    b_memory = b_memory && (new2dArrayMatlabProtocal(adjMatrix2d,adjMatrix1d,nnode,nnode));
    b_memory = b_memory && (new1dArrayMatlabProtocal(nodeParent,nnode));
  }
  if (!b_memory) {
    delocatememory();
    return 0; //fail
  }
  else
    return 1; //success
}
void BFSClass::delocatememory() 
{
  delete1dArrayMatlabProtocal(nodeColor);
  delete1dArrayMatlabProtocal(nodeDetectTime);
  delete1dArrayMatlabProtocal(nodeFinishTime);
  delete1dArrayMatlabProtocal(nodeLabel);
  delete1dArrayMatlabProtocal(nodeParent);
  delete2dArrayMatlabProtocal(adjMatrix2d,adjMatrix1d);
}

//main program

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  //check data 
  
  if(nrhs < 2) {
    printf("Usage [node_attribute] = progname(adjArray2d,rootnode).\n");
    printf("node_attr = [color,label,parent,dtime,ftime].\n");
    mexErrMsgTxt("No input para specified. Exit.");
  }
  if(nlhs > 1)
    mexErrMsgTxt("Too many output arguments <labelled_rgn>.");

  //copy data

  void *inimg = (void *)mxGetPr(prhs[0]);
  const long totalpxlnum = mxGetNumberOfElements(prhs[0]);
  mxClassID inimgtype = mxGetClassID(prhs[0]);
  long cwid = (long)mxGetN(prhs[0]);
  long chei = (long)mxGetM(prhs[0]);
  if(cwid!=chei) {
    mexErrMsgTxt("the connectivity matrix has to be square!");
  }

  long rootnode = (long)(*mxGetPr(prhs[1]));

  BFSClass * pBFS = new BFSClass;
  if (!pBFS)
    {mexErrMsgTxt("Fail to allocate memory for DFSClass().");}
  pBFS->nnode = chei;
  pBFS->allocatememory(pBFS->nnode);

  int nstate;
  UBYTE minlevel,maxlevel;
  switch(inimgtype) {
  case mxINT8_CLASS: 
    copyvecdata_T2UB((BYTE *)inimg,totalpxlnum,pBFS->adjMatrix1d,
		nstate,minlevel,maxlevel); 
    break;
  case mxUINT8_CLASS: 
    copyvecdata_T2UB((UBYTE *)inimg,totalpxlnum,pBFS->adjMatrix1d,
		nstate,minlevel,maxlevel); 
    break;
  case mxDOUBLE_CLASS: 
    copyvecdata_T2UB((double *)inimg,totalpxlnum,pBFS->adjMatrix1d,
		nstate,minlevel,maxlevel); 
    break;
  default:
    mexErrMsgTxt("Unsupported data type.");
    break;
  } 

  //printf("min=%i max=%i\n",minlevel,maxlevel);

  pBFS->setrootnode(rootnode-1); //change from Matlab convention to C convention

  //begin computation
  pBFS->dosearch();

  //printf("then --> phcDebugRgnNum=%i phcDebugPosNum=%i\n",phcDebugRgnNum,phcDebugPosNum);

  //create the Matlab structure array

  plhs[0] = mxCreateDoubleMatrix(pBFS->nnode,5,mxREAL);
  double * out_nodeColor = mxGetPr(plhs[0]);
  double * out_nodeLabel = out_nodeColor + pBFS->nnode;
  double * out_nodeParent = out_nodeLabel + pBFS->nnode;
  double * out_nodeDetectTime = out_nodeParent + pBFS->nnode;
  double * out_nodeFinishTime = out_nodeDetectTime + pBFS->nnode;
  for (long i=0;i<pBFS->nnode;i++) {
    out_nodeColor[i] = pBFS->nodeColor[i];
    out_nodeLabel[i] = pBFS->nodeLabel[i];
    out_nodeParent[i] = pBFS->nodeParent[i];
    out_nodeDetectTime[i] = pBFS->nodeDetectTime[i];
    out_nodeFinishTime[i] = pBFS->nodeFinishTime[i];
  }

  //free memory and return

  if (pBFS) {delete pBFS;}
  return;
}

