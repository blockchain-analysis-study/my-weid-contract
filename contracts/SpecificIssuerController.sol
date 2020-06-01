pragma solidity ^0.4.4;
/*
 *       Copyright© (2019) WeBank Co., Ltd.
 *
 *       This file is part of weidentity-contract.
 *
 *       weidentity-contract is free software: you can redistribute it and/or modify
 *       it under the terms of the GNU Lesser General Public License as published by
 *       the Free Software Foundation, either version 3 of the License, or
 *       (at your option) any later version.
 *
 *       weidentity-contract is distributed in the hope that it will be useful,
 *       but WITHOUT ANY WARRANTY; without even the implied warranty of
 *       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *       GNU Lesser General Public License for more details.
 *
 *       You should have received a copy of the GNU Lesser General Public License
 *       along with weidentity-contract.  If not, see <https://www.gnu.org/licenses/>.
 */

import "./SpecificIssuerData.sol";
import "./RoleController.sol";

/**
 * @title SpecificIssuerController
 * Controller contract managing issuers with specific types info.
 */

// todo 特殊发行人 流程控制合约
//
// WeIdentity支持为每位Authority Issuer在链上声明所属类型，即Specific Issuer
// 您可以指定某位Authority Issuer的具体类型属性，如学校、政府机构、医院等。
// 当前，此属性与其对应的权限没有直接关系，仅作记录之目的。
//
// todo 由此可知, SpecificIssuer 其实就是为 AuthorityIssuer 做记录的
contract SpecificIssuerController {

    // 特殊发行人 数据合约
    SpecificIssuerData private specificIssuerData;
    // 权限合约
    RoleController private roleController;

    // Event structure to store tx records
    // 用于存储TX记录的事件结构

    // event 的key
    uint constant private OPERATION_ADD = 0;
    uint constant private OPERATION_REMOVE = 1;

    // 特殊发行人的 操作动作event
    event SpecificIssuerRetLog(
        uint operation,             // 操作类型
        uint retCode,               // 结果状态码
        bytes32 typeName,           // 发行者类型Name
        address addr                // 发行者的WeId
    );

    // Constructor.
    // 构造函数
    function SpecificIssuerController(
        address specificIssuerDataAddress,
        address roleControllerAddress
    )
        public
    {
        specificIssuerData = SpecificIssuerData(specificIssuerDataAddress);
        roleController = RoleController(roleControllerAddress);
    }

    // 注册一个新的 发行者 类型
    function registerIssuerType(bytes32 typeName) public {
        uint result = specificIssuerData.registerIssuerType(typeName);
        SpecificIssuerRetLog(OPERATION_ADD, result, typeName, 0x0);
    }

    function isIssuerTypeExist(bytes32 typeName) public constant returns (bool) {
        return specificIssuerData.isIssuerTypeExist(typeName);
    }

    function addIssuer(bytes32 typeName, address addr) public {
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_KEY_CPT())) {
            SpecificIssuerRetLog(OPERATION_ADD, roleController.RETURN_CODE_FAILURE_NO_PERMISSION(), typeName, addr);
            return;
        }
        uint result = specificIssuerData.addIssuer(typeName, addr);
        SpecificIssuerRetLog(OPERATION_ADD, result, typeName, addr);
    }

    function removeIssuer(bytes32 typeName, address addr) public {
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_KEY_CPT())) {
            SpecificIssuerRetLog(OPERATION_REMOVE, roleController.RETURN_CODE_FAILURE_NO_PERMISSION(), typeName, addr);
            return;
        }
        uint result = specificIssuerData.removeIssuer(typeName, addr);
        SpecificIssuerRetLog(OPERATION_REMOVE, result, typeName, addr);
    }

    function addExtraValue(bytes32 typeName, bytes32 extraValue) public {
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_KEY_CPT())) {
            SpecificIssuerRetLog(OPERATION_ADD, roleController.RETURN_CODE_FAILURE_NO_PERMISSION(), typeName, 0x0);
            return;
        }
        uint result = specificIssuerData.addExtraValue(typeName, extraValue);
        SpecificIssuerRetLog(OPERATION_ADD, result, typeName, 0x0);
    }

    function getExtraValue(bytes32 typeName) public constant returns (bytes32[]) {
        bytes32[8] memory tempArray = specificIssuerData.getExtraValue(typeName);
        bytes32[] memory resultArray = new bytes32[](8);
        for (uint index = 0; index < 8; index++) {
            resultArray[index] = tempArray[index];
        }
        return resultArray;
    }

    function isSpecificTypeIssuer(bytes32 typeName, address addr) public constant returns (bool) {
        return specificIssuerData.isSpecificTypeIssuer(typeName, addr);
    }

    function getSpecificTypeIssuerList(bytes32 typeName, uint startPos, uint num) public constant returns (address[]) {
        if (num == 0 || !specificIssuerData.isIssuerTypeExist(typeName)) {
            return new address[](50);
        }

        // Calculate actual dataLength via batch return for better perf
        uint totalLength = specificIssuerData.getSpecificTypeIssuerLength(typeName);
        uint dataLength;
        if (totalLength < startPos) {
            return new address[](50);
        } else {
            if (totalLength <= startPos + num) {
                dataLength = totalLength - startPos;
            } else {
                dataLength = num;
            }
        }

        address[] memory resultArray = new address[](dataLength);
        address[50] memory tempArray;
        tempArray = specificIssuerData.getSpecificTypeIssuers(typeName, startPos);
        uint tick;
        if (dataLength <= 50) {
            for (tick = 0; tick < dataLength; tick++) {
                resultArray[tick] = tempArray[tick];
            }
        } else {
            for (tick = 0; tick < 50; tick++) {
                resultArray[tick] = tempArray[tick];
            }
        }
        return resultArray;
    }
}