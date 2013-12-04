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
module kernel.common;

/**
 Include architecture dependent modules
 */
public
{
	import kernel.trace.trace;
	import kernel.trace.device;
	import kernel.trace.e9;
	import kernel.trace.uart;
	import kernel.trace.vga;

	version(X86_64)
	{
		public import kernel.arch.x86.architecture;
	} else version(X86)
	{
		public import kernel.arch.x86.architecture;
	}

	public import core.stdc.stdint;
	public import core.vararg;
}