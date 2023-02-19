//
//  main.swift
//  simplevmm
//
//  Created by David Albert on 2/18/23.
//

import Foundation
import Darwin
import Hypervisor

// Normally you'd #include <mach/vm_param.h> to get this, but
// it doesn't seem to be exported in Swift. It's defined in
// <mach/arm/vm_param.h>.
var PAGE_SIZE: size_t {
    size_t(vm_page_size)
}

extension hv_return_t {
    public var description: String {
        switch Int(self) {
        case HV_SUCCESS: return "HV_SUCCESS"
        case HV_ERROR: return "HV_ERROR"
        case HV_BUSY: return "HV_BUSY"
        case HV_BAD_ARGUMENT: return "HV_BAD_ARGUMENT"
        case HV_ILLEGAL_GUEST_STATE: return "HV_ILLEGAL_GUEST_STATE"
        case HV_NO_RESOURCES: return "HV_NO_RESOURCES"
        case HV_NO_DEVICE: return "HV_NO_DEVICE"
        case HV_DENIED: return "HV_DENIED"
        case HV_UNSUPPORTED: return "HV_UNSUPPORTED"
        default: return "(hv_return_t 0x\(String(UInt32(bitPattern: self), radix: 16)))"
        }
    }
}

var bootcode: [UInt8] = [
    0x00, 0x00, 0x88, 0xd2,      // mov    x0, #0x4000 // uart address
    0x01, 0x09, 0x80, 0xd2,      // mov    w1, 'h'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0xa1, 0x0c, 0x80, 0xd2,      // mov    w1, 'e'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0x81, 0x0d, 0x80, 0xd2,      // mov    w1, 'l'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0x81, 0x0d, 0x80, 0xd2,      // mov    w1, 'l'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0xe1, 0x0d, 0x80, 0xd2,      // mov    w1, 'o'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0x01, 0x04, 0x80, 0xd2,      // mov    w1, ' '
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0xe1, 0x0e, 0x80, 0xd2,      // mov    w1, 'w'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0xe1, 0x0d, 0x80, 0xd2,      // mov    w1, 'o'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0x41, 0x0e, 0x80, 0xd2,      // mov    w1, 'r'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0x81, 0x0d, 0x80, 0xd2,      // mov    w1, 'l'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0x81, 0x0c, 0x80, 0xd2,      // mov    w1, 'd'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0x21, 0x04, 0x80, 0xd2,      // mov    w1, '!'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]
    0x41, 0x01, 0x80, 0xd2,      // mov    w1, '\n'
    0x01, 0x00, 0x00, 0x39,      // strb   x1, [x0]

    0x40, 0x00, 0x80, 0xd2,      // mov    x0, #2
    0x00, 0x08, 0x00, 0x91,      // add    x0, x0, #2
    0xc2, 0x5f, 0x19, 0xd4       // hvc    #0xcafe
]

func panic(_ s: String) -> Never {
    print("panic:", s)
    exit(1)
}

func hv_assert(_ s: String, _ ret: hv_return_t) {
    if ret != HV_SUCCESS {
        panic("\(s) \(ret.description)")
    }
}

func vcpu_main() {
    var vcpu: hv_vcpu_t = 0
    var vexit: UnsafeMutablePointer<hv_vcpu_exit_t>? = nil

    var uart = UART(outputStream: FileHandle.standardOutput)

    hv_assert("hv_vcpu_create", hv_vcpu_create(&vcpu, &vexit, nil))
    hv_assert("hv_vcpu_set_reg HV_REG_PC", hv_vcpu_set_reg(vcpu, HV_REG_PC, 0))

    // CPSR doesn't exist in aarch64, and the bits we're setting don't make sense
    // for the 32-bit version of CPSR. I believe these bits should be interpreted
    // as if they were used for SPSR_ELx. Specifically:
    //
    // - D[9], A[8], I[7], F[6] - all masked
    // - M[4] - 64 bit mode
    // - M[3:0] - 0b0101 - EL1h
    hv_assert("hv_vcpu_set_reg HV_REG_CPSR", hv_vcpu_set_reg(vcpu, HV_REG_CPSR, 0x3c5));

    guard let vexit = vexit else {
        panic("vexit is nil")
    }

    while true {
        hv_assert("hv_vcpu_run", hv_vcpu_run(vcpu))

        if vexit.pointee.reason == HV_EXIT_REASON_EXCEPTION {
            let esr_el2 = vexit.pointee.exception.syndrome

            let exceptionClass = (esr_el2 >> 26) & 0x3f

            if exceptionClass == 0x16 {
                // HVC in AArch64
                let arg = esr_el2 & 0xffff
                var x0: UInt64 = 0
                hv_assert("read reg", hv_vcpu_get_reg(vcpu, HV_REG_X0, &x0))

                print(String(format: "hvc #0x%x", arg))
                print("x0 = \(x0)")
                break
            } else if exceptionClass == 0x24 {
                // Data Abort exception from a lower EL taken to EL2
                let dfsc = esr_el2 & 0x3f

                if dfsc & (1<<2) != 0 {
                    // Translation fault
                    let isv = (esr_el2 >> 24) & 1

                    if isv != 1 {
                        panic("isv must be set")
                    }

                    let lst = (esr_el2 >> 11) & 3

                    if lst != 0 {
                        panic("ST64BV/LD64B/ST64B/ST64BV0 data abort not implemented")
                    }

                    let cm = (esr_el2 >> 8) & 1

                    if cm == 1 {
                        panic("cache maintenance data abort not implemented")
                    }

                    let ipa = vexit.pointee.exception.physical_address
                    let write = esr_el2 & (1<<6) != 0
                    let srt = (esr_el2 >> 16) & 0x1f

                    if ipa != 0x4000 {
                        panic(String(format: "read or write to address 0x%x not implemented", ipa))
                    }

                    if write {
                        let reg = hv_reg_t(UInt32(srt))
                        var value: UInt64 = 0
                        hv_assert("hv_vcpu_get_reg", hv_vcpu_get_reg(vcpu, reg, &value))

                        uart.tx = UInt8(value)
                    } else {
                        panic("read not implemented")
                    }
                } else {
                    panic("data abort: \(String(format: "ESR_EL2=0x%x IPA=0x%x FAR_EL2=0x%x", vexit.pointee.exception.syndrome, vexit.pointee.exception.physical_address, vexit.pointee.exception.virtual_address))")
                }

                var pc: UInt64 = 0
                hv_assert("get pc", hv_vcpu_get_reg(vcpu, HV_REG_PC, &pc))
                pc += 4
                hv_assert("set pc", hv_vcpu_set_reg(vcpu, HV_REG_PC, pc))
            } else {
                panic("unknown exception class \(exceptionClass)")
            }
        } else {
            panic("unknown exit reason \(vexit.pointee.reason)")
        }
    }

    hv_assert("hv_vcpu_destroy", hv_vcpu_destroy(vcpu))
}

hv_assert("hv_vm_create", hv_vm_create(nil))

var mem: UnsafeMutableRawPointer? = nil
let memsz = PAGE_SIZE

hv_assert("hv_vm_allocate", hv_vm_allocate(&mem, memsz, hv_allocate_flags_t(HV_ALLOCATE_DEFAULT)))

guard let mem = mem else {
    panic("hv_vm_allocate returned nil")
}

mem.initializeMemory(as: UInt8.self, repeating: 0, count: memsz)
mem.copyMemory(from: bootcode, byteCount: bootcode.count)

hv_assert("hv_vm_map", hv_vm_map(mem, 0, memsz, hv_memory_flags_t(HV_MEMORY_READ | HV_MEMORY_EXEC)))

vcpu_main()

hv_assert("hv_vm_unmap", hv_vm_unmap(0, memsz))
hv_assert("hv_vm_deallocate", hv_vm_deallocate(mem, memsz))
hv_assert("hv_vm_destroy", hv_vm_destroy())
