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

import kernel.common;

/**
 Exokid - an EXOKernel In D
 */
class Kernel
{
	/**
	 Initialisiert den Kernel via Multiboot2.
	 */
	public static void Initialize( ulong multibootMagic, ulong* multibootInfo )
	{
		Config.Initialize( multibootMagic, multibootInfo );

		Trace.Initialize( Trace.Device.VGA | Trace.Device.E9 | Trace.Device.UART );

		Trace.printf( "Exokid kernel booting via %s...\n\n", Multiboot2.bootLoader );
		Trace.printf( " * Commandline: %s\n", Multiboot2.commandLine );
		Trace.printf( " * Framebuffer: %x, %d:%d\n", Config.frameBuffer, Config.consoleColumns, Config.consoleRows );

		Architecture.Initialize();

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