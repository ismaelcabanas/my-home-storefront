import "reflect-metadata";

import { NextRequest, NextResponse } from "next/server";

import { InventoryItemCreator } from "../../../../contexts/inventory/inventory-items/application/create/InventoryItemCreator";
import { InvalidInventoryItemNameError } from "../../../../contexts/inventory/inventory-items/domain/InvalidInventoryItemNameError";
import { container } from "../../../../contexts/shared/infrastructure/dependency-injection/diod.config";
import { HttpNextResponse } from "../../../../contexts/shared/infrastructure/http/HttpNextResponse";

const creator = container.get(InventoryItemCreator);

export async function POST(request: NextRequest): Promise<NextResponse> {
	try {
		const body = (await request.json()) as { name?: string };
		const name = body.name ?? "";

		const item = await creator.create(name);

		return HttpNextResponse.created(item);
	} catch (error) {
		if (error instanceof InvalidInventoryItemNameError) {
			return HttpNextResponse.badRequest(
				"El nombre del producto es obligatorio",
			);
		}

		throw error;
	}
}
