module cujit;
import dllvm;
public import cujit.engine;


/**
    Initialize the JIT framework
*/
void initJIT() {
    loadLLVM();
    initExecutionEngine();
}
