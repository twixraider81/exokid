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
module kernel.arch.x86.architecture;

version(X86_64)
{
	public
	{
		import kernel.boot.multiboot2;
		import kernel.arch.x86.x64.state;
	}
}
else version(X86)
{
	public
	{
		import kernel.boot.multiboot2;
		import kernel.arch.x86.x32.state;
	}
}

public
{
	import kernel.arch.x86.config;

	import kernel.arch.x86.cpu;

	import kernel.arch.x86.mem.gdt;
	import kernel.arch.x86.mem.physmem;

	import kernel.arch.x86.intr.idt;
	import kernel.arch.x86.intr.pic;

	import kernel.arch.x86.io.common;
	import kernel.arch.x86.io.bda;
	import kernel.arch.x86.io.port;
	import kernel.arch.x86.io.serial;

	import kernel.trace.trace;
}

/**
 x86 Architecture interface
 */
class Architecture
{
	/**
	 Initialize common hardware structures
	 */
	public static bool Initialize()
	{
		Cpu.Initialize();

		Cpu.gdt.Initialize();

		Cpu.idt.Initialize();

		Cpu.pic.Initialize();

		Cpu.idt.Enable();

		PhysMem.Initialize();

		return true;
	}
}