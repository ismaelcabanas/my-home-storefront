import "reflect-metadata";

import { NextRequest, NextResponse } from "next/server";

import { InventoryItemDepleter } from "../../../../../../contexts/inventory/inventory-items/application/deplete/InventoryItemDepleter";
import { InventoryItemNotFoundError } from "../../../../../../contexts/inventory/inventory-items/domain/InventoryItemNotFoundError";
import { CodelyError } from "../../../../../../contexts/shared/domain/CodelyError";
import { container } from "../../../../../../contexts/shared/infrastructure/dependency-injection/diod.config";
import { HttpNextResponse } from "../../../../../../contexts/shared/infrastructure/http/HttpNextResponse";

const depleter = container.get(InventoryItemDepleter);

export async function POST(
	_request: NextRequest,
	{ params }: { params: Promise<{ id: string }> },
): Promise<NextResponse> {
	try {
		const { id } = await params;
		const item = await depleter.deplete(id);

		return HttpNextResponse.ok(item);
	} catch (error) {
		if (error instanceof InventoryItemNotFoundError) {
			return HttpNextResponse.notFound();
		}

		if (error instanceof CodelyError) {
			return HttpNextResponse.codelyError(error, 404);
		}

		throw error;
	}
}
