/**
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
module kernel.kernel;

import core.stdc.stdint;
import kernel.trace.trace;
import kernel.config;
import kernel.arch.architecture;
import kernel.mem.memory;

/**
 Exokid - an EXOKernel In D
 */
class Kernel
{
	/**
	 Initialisiert den Kernel via Multiboot2.
	 */
	public static void Initialize( uint32_t multibootMagic, uintptr_t* multibootInfo )
	{
		Trace.Initialize( Trace.Device.VGA | Trace.Device.E9 | Trace.Device.UART );
		Config.Initialize( multibootMagic, multibootInfo );

		//Trace.printf( "Exokid kernel booting via %s...\n\n", Multiboot2.bootLoader );
		Trace.print( "Exokid kernel booting...\n\n" );
		Trace.printf( " * Commandline: %s\n", Config.commandLine );
		Trace.printf( " * Framebuffer: %x, %d:%d\n", Config.frameBuffer, Config.consoleColumns, Config.consoleRows );

		Architecture.Initialize();
		
		Memory.Initialize();

		Run();
	}

	/**
	 Kernel main loop
	 */
	public static void Run()
	{
		while(true) {
			Cpu.Noop();
		}
	}

	/**
	 Initialize kernel shutdown
	 */
	public static void Shutdown()
	{
		Trace.print( "\n\nSystem halted." );
		Cpu.Halt();
	}
}