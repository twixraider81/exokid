/**
 Inkludiert allgemein benutzte Module
 */
module kernel.common;

public
{
	import kernel.console.trace;
	import kernel.console.device;
	import kernel.console.e9;
	import kernel.console.uart;
	import kernel.console.vga;

	version(X86_64)
	{
		public import kernel.arch.x64.architecture;
	}

	// aus der d runtime
	public import core.vararg;
}