/**
 Exokid - An EXOKernel In D
 */
module kernel.kernel;

import kernel.common;

/**
 Der eigentliche Kernel
 */
class Kernel
{
	/**
	 Initialisiert den Kernel via Multiboot2.
	 multibootMagic & multibootInfo Pointer müssen vom Bootloader übergeben werden
	 */
	public static void Initialize( ulong multibootMagic, ulong* multibootInfo )
	{
		if( !Multiboot2.Initialize( multibootMagic, PhysMem.ptrToVirtual( multibootInfo ) ) ) {

			Trace.Initialize();
			Trace.printf( "Wrong multiboot magic: %x !", multibootMagic );

			Cpu.Halt();
			return; // eher symbolischer natur...
		}

		Config.Initialize();
		Trace.Initialize( Trace.Device.VGA | Trace.Device.E9 | Trace.Device.UART );

		Trace.printf( "Exokid kernel booting via %s...\n\n", Multiboot2.bootLoader );
		Trace.printf( " * Commandline: %s\n", Multiboot2.commandLine );
		Trace.printf( " * Framebuffer: %x, %d:%d\n", Config.frameBuffer, Config.consoleColumns, Config.consoleRows );

		Architecture.Initialize();

		Run();
	}

	/**
	 Kernel Hauptschleife
	 */
	public static void Run()
	{
		while(true) {
			Cpu.Noop();
		}
	}

	/**
	 Leitet den Shutdown des Kernel ein
	 */
	public static void Shutdown()
	{
		Trace.print( "\n\nSystem halted." );
		Cpu.Halt();
	}
}